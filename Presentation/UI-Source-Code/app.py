"""
Gym Membership and Fitness Session Management System
DBMS Course Project - User Interface (Flask + MySQL)

Run:
    pip install -r requirements.txt
    python app.py
Then open http://127.0.0.1:5000 in a browser.

Every page talks to the MySQL database `gym_management` created by
gym_management.sql. Each screen supports VIEW, INSERT and DELETE.
"""
from datetime import date, timedelta

import pymysql
from flask import Flask, flash, redirect, render_template, request, url_for

import config

app = Flask(__name__)
app.secret_key = "dbms-course-project"


# ---------------------------------------------------------------- database
def get_connection():
    """Open a new connection to the MySQL database."""
    return pymysql.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        database=config.DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
    )


def fetch_all(sql, params=()):
    """Run a SELECT statement and return all rows as a list of dictionaries."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()
    finally:
        conn.close()


def run(sql, params=()):
    """Run an INSERT / UPDATE / DELETE statement and commit it.
    Returns the number of rows affected."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            affected = cur.execute(sql, params)
        conn.commit()
        return affected
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def explain(error):
    """Turn a MySQL error into a message a user can understand."""
    code = error.args[0] if error.args else 0
    if code == 1062:
        return "Not saved: this value already exists (UNIQUE constraint)."
    if code == 1452:
        return "Not saved: the linked record does not exist (FOREIGN KEY constraint)."
    if code == 1451:
        return "Cannot delete: other records still depend on this one (FOREIGN KEY, ON DELETE RESTRICT)."
    if code in (3819, 4025):
        return "Not saved: a value is outside the allowed range (CHECK constraint)."
    return f"Database error {code}: {error.args[-1]}"


def save(sql, params, success):
    """Run a change, then flash either the success text or the MySQL error."""
    try:
        run(sql, params)
        flash(success, "ok")
    except pymysql.MySQLError as error:
        flash(explain(error), "error")


# --------------------------------------------------------------- dashboard
@app.route("/")
def dashboard():
    counts = fetch_all(
        """SELECT (SELECT COUNT(*) FROM member)                             AS members,
                  (SELECT COUNT(*) FROM membership WHERE status = 'Active') AS active_memberships,
                  (SELECT COUNT(*) FROM trainer)                            AS trainers,
                  (SELECT COUNT(*) FROM fitness_session)                    AS sessions,
                  (SELECT COUNT(*) FROM booking)                            AS bookings,
                  (SELECT COALESCE(SUM(amount), 0) FROM payment)            AS revenue"""
    )[0]
    upcoming = fetch_all(
        """SELECT s.session_name, s.session_type, t.trainer_name, s.session_date,
                  s.start_time, s.room, s.capacity, COUNT(b.booking_id) AS booked
           FROM fitness_session s
           JOIN trainer t      ON t.trainer_id = s.trainer_id
           LEFT JOIN booking b ON b.session_id = s.session_id
           GROUP BY s.session_id
           ORDER BY s.session_date, s.start_time"""
    )
    return render_template("dashboard.html", counts=counts, upcoming=upcoming)


# ----------------------------------------------------------------- members
@app.route("/members")
def members():
    rows = fetch_all(
        """SELECT m.*, TIMESTAMPDIFF(YEAR, m.dob, CURDATE()) AS age,
                  (SELECT p.plan_name
                   FROM membership ms JOIN membership_plan p ON p.plan_id = ms.plan_id
                   WHERE ms.member_id = m.member_id AND ms.status = 'Active'
                   ORDER BY ms.end_date DESC LIMIT 1) AS active_plan
           FROM member m ORDER BY m.member_id"""
    )
    return render_template("members.html", rows=rows, today=date.today().isoformat())


@app.route("/members/add", methods=["POST"])
def add_member():
    f = request.form
    save(
        """INSERT INTO member (first_name, last_name, gender, dob, phone, email, city, join_date)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
        (f["first_name"].strip(), f["last_name"].strip(), f["gender"], f["dob"],
         f["phone"].strip(), f["email"].strip(), f["city"].strip(), f["join_date"]),
        f"Member {f['first_name']} {f['last_name']} inserted into table MEMBER.",
    )
    return redirect(url_for("members"))


@app.route("/members/delete/<int:member_id>", methods=["POST"])
def delete_member(member_id):
    save("DELETE FROM member WHERE member_id = %s", (member_id,),
         f"Member #{member_id} deleted. Their memberships, payments and bookings "
         "were removed by ON DELETE CASCADE.")
    return redirect(url_for("members"))


# ---------------------------------------------------------------- trainers
@app.route("/trainers")
def trainers():
    rows = fetch_all(
        """SELECT t.*, COUNT(s.session_id) AS sessions
           FROM trainer t LEFT JOIN fitness_session s ON s.trainer_id = t.trainer_id
           GROUP BY t.trainer_id ORDER BY t.trainer_id"""
    )
    return render_template("trainers.html", rows=rows)


@app.route("/trainers/add", methods=["POST"])
def add_trainer():
    f = request.form
    save(
        """INSERT INTO trainer (trainer_name, specialization, phone, email, experience_years)
           VALUES (%s, %s, %s, %s, %s)""",
        (f["trainer_name"].strip(), f["specialization"], f["phone"].strip(),
         f["email"].strip(), f["experience_years"]),
        f"Trainer {f['trainer_name']} inserted into table TRAINER.",
    )
    return redirect(url_for("trainers"))


@app.route("/trainers/delete/<int:trainer_id>", methods=["POST"])
def delete_trainer(trainer_id):
    save("DELETE FROM trainer WHERE trainer_id = %s", (trainer_id,),
         f"Trainer #{trainer_id} deleted from table TRAINER.")
    return redirect(url_for("trainers"))


# ---------------------------------------------------------------- sessions
SESSION_TYPES = ["Yoga", "Strength", "Zumba", "CrossFit", "Cardio", "Pilates"]


@app.route("/sessions")
def sessions():
    rows = fetch_all(
        """SELECT s.*, t.trainer_name, COUNT(b.booking_id) AS booked
           FROM fitness_session s
           JOIN trainer t      ON t.trainer_id = s.trainer_id
           LEFT JOIN booking b ON b.session_id = s.session_id
           GROUP BY s.session_id
           ORDER BY s.session_date, s.start_time"""
    )
    trainer_list = fetch_all("SELECT trainer_id, trainer_name, specialization FROM trainer ORDER BY trainer_name")
    return render_template("sessions.html", rows=rows, trainers=trainer_list,
                           types=SESSION_TYPES, today=date.today().isoformat())


@app.route("/sessions/add", methods=["POST"])
def add_session():
    f = request.form
    save(
        """INSERT INTO fitness_session
               (session_name, session_type, trainer_id, session_date, start_time, duration_min, capacity, room)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
        (f["session_name"].strip(), f["session_type"], f["trainer_id"], f["session_date"],
         f["start_time"], f["duration_min"], f["capacity"], f["room"].strip()),
        f"Session '{f['session_name']}' inserted into table FITNESS_SESSION.",
    )
    return redirect(url_for("sessions"))


@app.route("/sessions/delete/<int:session_id>", methods=["POST"])
def delete_session(session_id):
    save("DELETE FROM fitness_session WHERE session_id = %s", (session_id,),
         f"Session #{session_id} deleted. Its bookings were removed by ON DELETE CASCADE.")
    return redirect(url_for("sessions"))


# ---------------------------------------------------------------- bookings
@app.route("/bookings")
def bookings():
    rows = fetch_all(
        """SELECT b.booking_id, CONCAT(m.first_name, ' ', m.last_name) AS member_name,
                  s.session_name, t.trainer_name, s.session_date, s.start_time,
                  b.booking_date, b.attendance
           FROM booking b
           JOIN member m          ON m.member_id  = b.member_id
           JOIN fitness_session s ON s.session_id = b.session_id
           JOIN trainer t         ON t.trainer_id = s.trainer_id
           ORDER BY b.booking_id"""
    )
    member_list = fetch_all("SELECT member_id, first_name, last_name FROM member ORDER BY first_name")
    session_list = fetch_all(
        """SELECT s.session_id, s.session_name, s.session_date, s.capacity, COUNT(b.booking_id) AS booked
           FROM fitness_session s LEFT JOIN booking b ON b.session_id = s.session_id
           GROUP BY s.session_id ORDER BY s.session_date, s.start_time"""
    )
    return render_template("bookings.html", rows=rows, members=member_list,
                           sessions=session_list, today=date.today().isoformat())


@app.route("/bookings/add", methods=["POST"])
def add_booking():
    f = request.form
    seats = fetch_all(
        """SELECT s.capacity, COUNT(b.booking_id) AS booked
           FROM fitness_session s LEFT JOIN booking b ON b.session_id = s.session_id
           WHERE s.session_id = %s GROUP BY s.session_id""",
        (f["session_id"],),
    )
    if seats and seats[0]["booked"] >= seats[0]["capacity"]:
        flash("Not saved: this session is already full.", "error")
    else:
        save(
            "INSERT INTO booking (member_id, session_id, booking_date) VALUES (%s, %s, %s)",
            (f["member_id"], f["session_id"], f["booking_date"]),
            "Booking inserted into table BOOKING.",
        )
    return redirect(url_for("bookings"))


@app.route("/bookings/delete/<int:booking_id>", methods=["POST"])
def delete_booking(booking_id):
    save("DELETE FROM booking WHERE booking_id = %s", (booking_id,),
         f"Booking #{booking_id} deleted from table BOOKING.")
    return redirect(url_for("bookings"))


# ------------------------------------------------------------- memberships
PAYMENT_MODES = ["Cash", "Card", "UPI", "Net Banking"]


@app.route("/memberships")
def memberships():
    rows = fetch_all(
        """SELECT ms.membership_id, CONCAT(m.first_name, ' ', m.last_name) AS member_name,
                  p.plan_name, p.price, ms.start_date, ms.end_date, ms.status,
                  COALESCE(SUM(pay.amount), 0) AS paid
           FROM membership ms
           JOIN member m          ON m.member_id = ms.member_id
           JOIN membership_plan p ON p.plan_id   = ms.plan_id
           LEFT JOIN payment pay  ON pay.membership_id = ms.membership_id
           GROUP BY ms.membership_id
           ORDER BY ms.membership_id"""
    )
    plans = fetch_all("SELECT * FROM membership_plan ORDER BY price")
    member_list = fetch_all("SELECT member_id, first_name, last_name FROM member ORDER BY first_name")
    return render_template("memberships.html", rows=rows, plans=plans, members=member_list,
                           modes=PAYMENT_MODES, today=date.today().isoformat())


@app.route("/memberships/add", methods=["POST"])
def add_membership():
    """Insert a membership and its first payment together, as one transaction."""
    f = request.form
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT duration_months, price FROM membership_plan WHERE plan_id = %s", (f["plan_id"],))
            plan = cur.fetchone()
            start = date.fromisoformat(f["start_date"])
            end = start + timedelta(days=30 * plan["duration_months"])
            cur.execute(
                "INSERT INTO membership (member_id, plan_id, start_date, end_date, status) VALUES (%s, %s, %s, %s, 'Active')",
                (f["member_id"], f["plan_id"], start, end),
            )
            cur.execute(
                "INSERT INTO payment (membership_id, amount, payment_date, payment_mode) VALUES (%s, %s, %s, %s)",
                (cur.lastrowid, plan["price"], start, f["payment_mode"]),
            )
        conn.commit()                      # both rows are saved together
        flash("Membership and payment inserted (one transaction, two tables).", "ok")
    except pymysql.MySQLError as error:
        conn.rollback()                    # neither row is saved
        flash(explain(error), "error")
    finally:
        conn.close()
    return redirect(url_for("memberships"))


@app.route("/memberships/delete/<int:membership_id>", methods=["POST"])
def delete_membership(membership_id):
    save("DELETE FROM membership WHERE membership_id = %s", (membership_id,),
         f"Membership #{membership_id} deleted. Its payments were removed by ON DELETE CASCADE.")
    return redirect(url_for("memberships"))


# ----------------------------------------------------------------- reports
@app.route("/reports")
def reports():
    revenue = fetch_all(
        """SELECT p.plan_name, COUNT(DISTINCT ms.membership_id) AS times_sold,
                  COALESCE(SUM(pay.amount), 0) AS revenue
           FROM membership_plan p
           LEFT JOIN membership ms ON ms.plan_id = p.plan_id
           LEFT JOIN payment pay   ON pay.membership_id = ms.membership_id
           GROUP BY p.plan_id ORDER BY revenue DESC"""
    )
    workload = fetch_all(
        """SELECT t.trainer_name, t.specialization,
                  COUNT(DISTINCT s.session_id) AS sessions_conducted,
                  COUNT(b.booking_id) AS total_bookings
           FROM trainer t
           LEFT JOIN fitness_session s ON s.trainer_id = t.trainer_id
           LEFT JOIN booking b         ON b.session_id = s.session_id
           GROUP BY t.trainer_id ORDER BY total_bookings DESC"""
    )
    modes = fetch_all(
        """SELECT payment_mode, COUNT(*) AS no_of_payments, SUM(amount) AS amount_collected
           FROM payment GROUP BY payment_mode ORDER BY amount_collected DESC"""
    )
    idle = fetch_all(
        """SELECT member_id, CONCAT(first_name, ' ', last_name) AS member_name, phone
           FROM member WHERE member_id NOT IN (SELECT member_id FROM booking)"""
    )
    return render_template("reports.html", revenue=revenue, workload=workload, modes=modes, idle=idle)


if __name__ == "__main__":
    app.run(debug=True)
