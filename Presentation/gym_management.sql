-- =====================================================================
--  DBMS COURSE PROJECT (Project No. 67)
--  Design and Implementation of a Database Management System for
--  Gym Membership and Fitness Session Management System
--
--  File    : gym_management.sql
--  DBMS    : MySQL 8.0 (also runs on MariaDB 10.4+)
--  Run as  : mysql -u root -p < gym_management.sql
--            (or open in MySQL Workbench and execute the whole script)
--
--  Sections
--    1. Database creation
--    2. Table creation (DDL) with primary keys, foreign keys, constraints
--    3. Data insertion (DML) - minimum 5 records per table
--    4. SELECT queries - basic, joins, aggregate functions, subqueries
--    5. View
--    6. UPDATE and DELETE demonstration
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. DATABASE CREATION
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS gym_management;
CREATE DATABASE gym_management;
USE gym_management;


-- ---------------------------------------------------------------------
-- 2. TABLE CREATION (DDL)
-- ---------------------------------------------------------------------

-- 2.1 MEMBERSHIP_PLAN : the plans the gym sells
CREATE TABLE membership_plan (
    plan_id          INT            AUTO_INCREMENT,
    plan_name        VARCHAR(50)    NOT NULL,
    duration_months  INT            NOT NULL,
    price            DECIMAL(8,2)   NOT NULL,
    description      VARCHAR(150),
    CONSTRAINT pk_plan          PRIMARY KEY (plan_id),
    CONSTRAINT uq_plan_name     UNIQUE (plan_name),
    CONSTRAINT chk_plan_months  CHECK (duration_months BETWEEN 1 AND 24),
    CONSTRAINT chk_plan_price   CHECK (price > 0)
);

-- 2.2 MEMBER : people registered at the gym
CREATE TABLE member (
    member_id   INT           AUTO_INCREMENT,
    first_name  VARCHAR(30)   NOT NULL,
    last_name   VARCHAR(30)   NOT NULL,
    gender      CHAR(1)       NOT NULL,
    dob         DATE          NOT NULL,
    phone       CHAR(10)      NOT NULL,
    email       VARCHAR(60)   NOT NULL,
    city        VARCHAR(40)   NOT NULL DEFAULT 'Hyderabad',
    join_date   DATE          NOT NULL,
    CONSTRAINT pk_member         PRIMARY KEY (member_id),
    CONSTRAINT uq_member_phone   UNIQUE (phone),
    CONSTRAINT uq_member_email   UNIQUE (email),
    CONSTRAINT chk_member_gender CHECK (gender IN ('M', 'F', 'O'))
);

-- 2.3 TRAINER : staff who conduct fitness sessions
CREATE TABLE trainer (
    trainer_id        INT           AUTO_INCREMENT,
    trainer_name      VARCHAR(60)   NOT NULL,
    specialization    VARCHAR(30)   NOT NULL,
    phone             CHAR(10)      NOT NULL,
    email             VARCHAR(60)   NOT NULL,
    experience_years  INT           NOT NULL DEFAULT 0,
    CONSTRAINT pk_trainer        PRIMARY KEY (trainer_id),
    CONSTRAINT uq_trainer_phone  UNIQUE (phone),
    CONSTRAINT uq_trainer_email  UNIQUE (email),
    CONSTRAINT chk_trainer_exp   CHECK (experience_years >= 0)
);

-- 2.4 MEMBERSHIP : one row each time a member buys / renews a plan
CREATE TABLE membership (
    membership_id  INT          AUTO_INCREMENT,
    member_id      INT          NOT NULL,
    plan_id        INT          NOT NULL,
    start_date     DATE         NOT NULL,
    end_date       DATE         NOT NULL,
    status         VARCHAR(10)  NOT NULL DEFAULT 'Active',
    CONSTRAINT pk_membership         PRIMARY KEY (membership_id),
    CONSTRAINT fk_membership_member  FOREIGN KEY (member_id)
        REFERENCES member (member_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_membership_plan    FOREIGN KEY (plan_id)
        REFERENCES membership_plan (plan_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_membership_dates  CHECK (end_date > start_date),
    CONSTRAINT chk_membership_status CHECK (status IN ('Active', 'Expired', 'Cancelled'))
);

-- 2.5 PAYMENT : fee payments made against a membership
CREATE TABLE payment (
    payment_id     INT            AUTO_INCREMENT,
    membership_id  INT            NOT NULL,
    amount         DECIMAL(8,2)   NOT NULL,
    payment_date   DATE           NOT NULL,
    payment_mode   VARCHAR(15)    NOT NULL,
    CONSTRAINT pk_payment             PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_membership  FOREIGN KEY (membership_id)
        REFERENCES membership (membership_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_payment_amount     CHECK (amount > 0),
    CONSTRAINT chk_payment_mode       CHECK (payment_mode IN ('Cash', 'Card', 'UPI', 'Net Banking'))
);

-- 2.6 FITNESS_SESSION : scheduled group classes, each led by one trainer
CREATE TABLE fitness_session (
    session_id    INT           AUTO_INCREMENT,
    session_name  VARCHAR(50)   NOT NULL,
    session_type  VARCHAR(20)   NOT NULL,
    trainer_id    INT           NOT NULL,
    session_date  DATE          NOT NULL,
    start_time    TIME          NOT NULL,
    duration_min  INT           NOT NULL,
    capacity      INT           NOT NULL,
    room          VARCHAR(30)   NOT NULL,
    CONSTRAINT pk_session           PRIMARY KEY (session_id),
    CONSTRAINT fk_session_trainer   FOREIGN KEY (trainer_id)
        REFERENCES trainer (trainer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_session_slot      UNIQUE (room, session_date, start_time),
    CONSTRAINT chk_session_type     CHECK (session_type IN
        ('Yoga', 'Strength', 'Zumba', 'CrossFit', 'Cardio', 'Pilates')),
    CONSTRAINT chk_session_duration CHECK (duration_min BETWEEN 15 AND 180),
    CONSTRAINT chk_session_capacity CHECK (capacity > 0)
);

-- 2.7 BOOKING : resolves the M:N relationship MEMBER <-> FITNESS_SESSION
CREATE TABLE booking (
    booking_id    INT          AUTO_INCREMENT,
    member_id     INT          NOT NULL,
    session_id    INT          NOT NULL,
    booking_date  DATE         NOT NULL,
    attendance    VARCHAR(10)  NOT NULL DEFAULT 'Booked',
    CONSTRAINT pk_booking          PRIMARY KEY (booking_id),
    CONSTRAINT fk_booking_member   FOREIGN KEY (member_id)
        REFERENCES member (member_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_booking_session  FOREIGN KEY (session_id)
        REFERENCES fitness_session (session_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_booking          UNIQUE (member_id, session_id),
    CONSTRAINT chk_booking_att     CHECK (attendance IN ('Booked', 'Attended', 'Missed', 'Cancelled'))
);

-- Check the structure
SHOW TABLES;
DESCRIBE member;
DESCRIBE fitness_session;


-- ---------------------------------------------------------------------
-- 3. DATA INSERTION (DML)
-- ---------------------------------------------------------------------

INSERT INTO membership_plan (plan_name, duration_months, price, description) VALUES
('Monthly Basic',       1,  1500.00, 'Gym floor access for one month'),
('Quarterly Standard',  3,  4000.00, 'Gym floor plus group sessions for three months'),
('Half-Yearly Plus',    6,  7500.00, 'Gym floor, group sessions and one diet consultation'),
('Annual Premium',     12, 13000.00, 'All access for a year with locker'),
('Student Monthly',     1,  1000.00, 'Discounted monthly plan for students with ID'),
('Annual Elite',       12, 18000.00, 'Annual Premium plus personal training');

INSERT INTO member (first_name, last_name, gender, dob, phone, email, city, join_date) VALUES
('Arjun',   'Reddy',  'M', '2001-03-14', '9876543210', 'arjun.reddy@example.com',   'Hyderabad',    '2026-06-01'),
('Sneha',   'Iyer',   'F', '1999-11-02', '9876543211', 'sneha.iyer@example.com',    'Secunderabad', '2026-07-10'),
('Rahul',   'Verma',  'M', '1995-07-21', '9876543212', 'rahul.verma@example.com',   'Hyderabad',    '2026-08-05'),
('Priya',   'Sharma', 'F', '2003-01-30', '9876543213', 'priya.sharma@example.com',  'Hyderabad',    '2026-09-15'),
('Karthik', 'Naidu',  'M', '1998-09-09', '9876543214', 'karthik.naidu@example.com', 'Sangareddy',   '2026-05-01'),
('Ananya',  'Gupta',  'F', '2002-05-17', '9876543215', 'ananya.gupta@example.com',  'Hyderabad',    '2026-08-20'),
('Vikram',  'Singh',  'M', '1990-12-05', '9876543216', 'vikram.singh@example.com',  'Secunderabad', '2026-01-10'),
('Meera',   'Joshi',  'F', '2004-08-25', '9876543217', 'meera.joshi@example.com',   'Hyderabad',    '2026-10-01');

INSERT INTO trainer (trainer_name, specialization, phone, email, experience_years) VALUES
('Rohit Malhotra', 'Strength', '9123456701', 'rohit.m@fitzone.example',   8),
('Divya Menon',    'Yoga',     '9123456702', 'divya.m@fitzone.example',   6),
('Imran Khan',     'CrossFit', '9123456703', 'imran.k@fitzone.example',   5),
('Lakshmi Rao',    'Zumba',    '9123456704', 'lakshmi.r@fitzone.example', 4),
('Suresh Kumar',   'Cardio',   '9123456705', 'suresh.k@fitzone.example', 10),
('Neha Kapoor',    'Pilates',  '9123456706', 'neha.k@fitzone.example',    3);

INSERT INTO membership (member_id, plan_id, start_date, end_date, status) VALUES
(1, 4, '2026-06-01', '2027-06-01', 'Active'),
(2, 2, '2026-07-10', '2026-10-10', 'Active'),
(3, 1, '2026-08-05', '2026-09-05', 'Expired'),
(3, 3, '2026-09-06', '2027-03-06', 'Active'),
(4, 5, '2026-09-15', '2026-10-15', 'Active'),
(5, 2, '2026-05-01', '2026-08-01', 'Expired'),
(6, 3, '2026-08-20', '2027-02-20', 'Active'),
(7, 4, '2026-01-10', '2027-01-10', 'Active');

INSERT INTO payment (membership_id, amount, payment_date, payment_mode) VALUES
(1, 13000.00, '2026-06-01', 'UPI'),
(2,  4000.00, '2026-07-10', 'Card'),
(3,  1500.00, '2026-08-05', 'Cash'),
(4,  4000.00, '2026-09-06', 'UPI'),
(4,  2000.00, '2026-09-20', 'UPI'),
(5,  1000.00, '2026-09-15', 'Cash'),
(6,  4000.00, '2026-05-01', 'Card'),
(7,  7500.00, '2026-08-20', 'Net Banking'),
(8, 13000.00, '2026-01-10', 'Card');

INSERT INTO fitness_session
    (session_name, session_type, trainer_id, session_date, start_time, duration_min, capacity, room) VALUES
('Morning Yoga Flow', 'Yoga',     2, '2026-10-05', '06:30:00', 60, 20, 'Studio A'),
('Strength Basics',   'Strength', 1, '2026-10-05', '18:00:00', 75, 12, 'Weights Floor'),
('Zumba Blast',       'Zumba',    4, '2026-10-06', '19:00:00', 45, 25, 'Studio B'),
('CrossFit WOD',      'CrossFit', 3, '2026-10-07', '07:00:00', 60, 15, 'Functional Zone'),
('HIIT Cardio Burn',  'Cardio',   5, '2026-10-08', '18:30:00', 40, 18, 'Cardio Zone'),
('Power Yoga',        'Yoga',     2, '2026-10-09', '07:00:00', 60, 20, 'Studio A'),
('Advanced Lifting',  'Strength', 1, '2026-10-10', '19:00:00', 90, 10, 'Weights Floor');

INSERT INTO booking (member_id, session_id, booking_date, attendance) VALUES
(1, 1, '2026-10-03', 'Attended'),
(2, 1, '2026-10-03', 'Attended'),
(4, 1, '2026-10-04', 'Missed'),
(6, 1, '2026-10-04', 'Attended'),
(1, 2, '2026-10-03', 'Attended'),
(3, 2, '2026-10-04', 'Attended'),
(7, 2, '2026-10-04', 'Missed'),
(2, 3, '2026-10-05', 'Attended'),
(4, 3, '2026-10-05', 'Attended'),
(3, 4, '2026-10-05', 'Booked'),
(7, 4, '2026-10-06', 'Booked'),
(3, 5, '2026-10-06', 'Booked'),
(6, 5, '2026-10-06', 'Booked'),
(1, 7, '2026-10-06', 'Booked'),
(7, 7, '2026-10-06', 'Booked');

-- Row counts of every table (each has at least 5 records)
SELECT 'membership_plan' AS table_name, COUNT(*) AS total_rows FROM membership_plan
UNION ALL SELECT 'member',          COUNT(*) FROM member
UNION ALL SELECT 'trainer',         COUNT(*) FROM trainer
UNION ALL SELECT 'membership',      COUNT(*) FROM membership
UNION ALL SELECT 'payment',         COUNT(*) FROM payment
UNION ALL SELECT 'fitness_session', COUNT(*) FROM fitness_session
UNION ALL SELECT 'booking',         COUNT(*) FROM booking;


-- ---------------------------------------------------------------------
-- 4. SELECT QUERIES
-- ---------------------------------------------------------------------

-- Q1. All members
SELECT * FROM member;

-- Q2. Members from Hyderabad who joined on or after 1 August 2026, newest first
SELECT member_id, first_name, last_name, city, join_date
FROM   member
WHERE  city = 'Hyderabad' AND join_date >= '2026-08-01'
ORDER  BY join_date DESC;

-- Q3. INNER JOIN (3 tables): every membership with member and plan details
SELECT ms.membership_id,
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       p.plan_name, ms.start_date, ms.end_date, ms.status
FROM   membership ms
JOIN   member m          ON m.member_id = ms.member_id
JOIN   membership_plan p ON p.plan_id   = ms.plan_id
ORDER  BY ms.membership_id;

-- Q4. INNER JOIN: session timetable with the trainer who conducts it
SELECT s.session_id, s.session_name, s.session_type, t.trainer_name,
       s.session_date, s.start_time, s.room
FROM   fitness_session s
JOIN   trainer t ON t.trainer_id = s.trainer_id
ORDER  BY s.session_date, s.start_time;

-- Q5. JOIN (4 tables): who has booked which session, and with which trainer
SELECT b.booking_id,
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       s.session_name, t.trainer_name, s.session_date, b.attendance
FROM   booking b
JOIN   member m          ON m.member_id  = b.member_id
JOIN   fitness_session s ON s.session_id = b.session_id
JOIN   trainer t         ON t.trainer_id = s.trainer_id
ORDER  BY s.session_date, member_name;

-- Q6. LEFT JOIN + COUNT: seats booked and seats left in every session
--     (sessions with no bookings still appear)
SELECT s.session_name, s.capacity,
       COUNT(b.booking_id)              AS seats_booked,
       s.capacity - COUNT(b.booking_id) AS seats_left
FROM   fitness_session s
LEFT   JOIN booking b ON b.session_id = s.session_id
GROUP  BY s.session_id, s.session_name, s.capacity
ORDER  BY seats_booked DESC;

-- Q7. LEFT JOIN + SUM: number of subscriptions and revenue for every plan
--     (plans nobody has bought still appear with zero)
SELECT p.plan_name,
       COUNT(DISTINCT ms.membership_id) AS times_sold,
       COALESCE(SUM(pay.amount), 0)     AS revenue
FROM   membership_plan p
LEFT   JOIN membership ms ON ms.plan_id = p.plan_id
LEFT   JOIN payment pay   ON pay.membership_id = ms.membership_id
GROUP  BY p.plan_id, p.plan_name
ORDER  BY revenue DESC;

-- Q8. Aggregate functions on payments
SELECT COUNT(*)              AS total_payments,
       SUM(amount)           AS total_collected,
       ROUND(AVG(amount), 2) AS average_payment,
       MIN(amount)           AS smallest_payment,
       MAX(amount)           AS largest_payment
FROM   payment;

-- Q9. GROUP BY: collection by payment mode
SELECT payment_mode, COUNT(*) AS no_of_payments, SUM(amount) AS amount_collected
FROM   payment
GROUP  BY payment_mode
ORDER  BY amount_collected DESC;

-- Q10. GROUP BY + HAVING: members who have booked more than two sessions
SELECT CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       COUNT(*) AS sessions_booked
FROM   booking b
JOIN   member m ON m.member_id = b.member_id
GROUP  BY m.member_id, member_name
HAVING COUNT(*) > 2
ORDER  BY sessions_booked DESC;

-- Q11. Trainer workload: sessions conducted and total bookings handled
SELECT t.trainer_name, t.specialization,
       COUNT(DISTINCT s.session_id) AS sessions_conducted,
       COUNT(b.booking_id)          AS total_bookings
FROM   trainer t
LEFT   JOIN fitness_session s ON s.trainer_id = t.trainer_id
LEFT   JOIN booking b         ON b.session_id = s.session_id
GROUP  BY t.trainer_id, t.trainer_name, t.specialization
ORDER  BY total_bookings DESC;

-- Q12. Subquery (NOT IN): members who have never booked a session
SELECT member_id, first_name, last_name
FROM   member
WHERE  member_id NOT IN (SELECT member_id FROM booking);

-- Q13. Subquery with aggregate: plans priced above the average plan price
SELECT plan_name, price
FROM   membership_plan
WHERE  price > (SELECT AVG(price) FROM membership_plan);

-- Q14. Balance due: plan price compared with what has been paid so far
SELECT ms.membership_id,
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       p.plan_name, p.price,
       COALESCE(SUM(pay.amount), 0)           AS paid,
       p.price - COALESCE(SUM(pay.amount), 0) AS balance_due
FROM   membership ms
JOIN   member m          ON m.member_id = ms.member_id
JOIN   membership_plan p ON p.plan_id   = ms.plan_id
LEFT   JOIN payment pay  ON pay.membership_id = ms.membership_id
GROUP  BY ms.membership_id, member_name, p.plan_name, p.price
HAVING balance_due > 0;

-- Q15. Attendance percentage per session type (completed bookings only)
SELECT s.session_type,
       SUM(b.attendance = 'Attended')                           AS attended,
       SUM(b.attendance = 'Missed')                             AS missed,
       ROUND(100 * SUM(b.attendance = 'Attended') / COUNT(*), 1) AS attendance_pct
FROM   booking b
JOIN   fitness_session s ON s.session_id = b.session_id
WHERE  b.attendance IN ('Attended', 'Missed')
GROUP  BY s.session_type;


-- ---------------------------------------------------------------------
-- 5. VIEW : members with their currently active plan
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_active_members AS
SELECT m.member_id,
       CONCAT(m.first_name, ' ', m.last_name) AS member_name,
       m.phone, p.plan_name, ms.end_date
FROM   member m
JOIN   membership ms     ON ms.member_id = m.member_id AND ms.status = 'Active'
JOIN   membership_plan p ON p.plan_id = ms.plan_id;

SELECT * FROM v_active_members ORDER BY end_date;


-- ---------------------------------------------------------------------
-- 6. UPDATE AND DELETE DEMONSTRATION
--    A temporary member is added, changed and removed, so the base data
--    above is left exactly as inserted.
-- ---------------------------------------------------------------------

-- 6.1 Insert a temporary member and give them a booking
INSERT INTO member (first_name, last_name, gender, dob, phone, email, city, join_date)
VALUES ('Demo', 'Member', 'M', '2000-01-01', '9000000000', 'demo.member@example.com', 'Hyderabad', '2026-10-06');

INSERT INTO booking (member_id, session_id, booking_date)
SELECT member_id, 6, '2026-10-06' FROM member WHERE phone = '9000000000';

SELECT * FROM member  WHERE phone = '9000000000';
SELECT b.* FROM booking b JOIN member m ON m.member_id = b.member_id WHERE m.phone = '9000000000';

-- 6.2 UPDATE the record
UPDATE member SET city = 'Secunderabad' WHERE phone = '9000000000';
SELECT member_id, first_name, city FROM member WHERE phone = '9000000000';

-- 6.3 DELETE the member; ON DELETE CASCADE removes the booking as well
DELETE FROM member WHERE phone = '9000000000';
SELECT COUNT(*) AS members_left  FROM member;
SELECT COUNT(*) AS bookings_left FROM booking;

-- Reset the counters so the next real member gets ID 9 and booking gets ID 16
ALTER TABLE member  AUTO_INCREMENT = 9;
ALTER TABLE booking AUTO_INCREMENT = 16;

-- 6.4 Constraint checks. Each statement below is rejected by MySQL.
--     Remove the leading "-- " and run one at a time to show the error.
-- INSERT INTO member (first_name, last_name, gender, dob, phone, email, join_date)
--     VALUES ('Dup', 'Phone', 'M', '2000-01-01', '9876543210', 'dup@example.com', '2026-10-06');   -- UNIQUE phone
-- INSERT INTO booking (member_id, session_id, booking_date) VALUES (1, 1, '2026-10-06');           -- UNIQUE (member, session)
-- INSERT INTO booking (member_id, session_id, booking_date) VALUES (99, 1, '2026-10-06');          -- FOREIGN KEY
-- INSERT INTO payment (membership_id, amount, payment_date, payment_mode) VALUES (1, -50, '2026-10-06', 'UPI');  -- CHECK
-- DELETE FROM trainer WHERE trainer_id = 1;                                                        -- ON DELETE RESTRICT

-- ============================= END OF FILE ============================
