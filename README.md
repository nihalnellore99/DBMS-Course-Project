# Design and Implementation of a Database Management System for Gym Membership and Fitness Session Management System

DBMS Course Project, Project No. 67

A MySQL database with a Flask web interface that manages a gym's members, membership plans, payments, trainers, fitness sessions and session bookings.

## Team

| Name | Roll number |
|---|---|
| Sai Nihal Nellore | 25WU0101118 |
| [Member 2 name] | [Roll number] |
| [Member 3 name] | [Roll number] |

## Repository contents

| Folder | Contents |
|---|---|
| `Presentation/` | Slides (`.pptx` and `.pdf`), `ER_Diagram.png`, `gym_management.sql`, UI source code, screenshots of every UI screen |
| `Project-Report/` | `Project_Report.pdf` |

## Database

Seven tables in third normal form: `membership_plan`, `member`, `trainer`, `membership`, `payment`, `fitness_session`, `booking`.

`Presentation/gym_management.sql` creates the database and tables (primary keys, foreign keys, UNIQUE and CHECK constraints), inserts the sample records, and runs 15 SELECT queries with joins, aggregate functions and subqueries.

## How to run

Requirements: MySQL 8.0 and Python 3.9 or later.

1. Create the database:

   ```
   mysql -u root -p < Presentation/gym_management.sql
   ```

2. Put your MySQL password in `Presentation/UI-Source-Code/config.py` (`DB_PASSWORD`).

3. Start the interface:

   ```
   cd Presentation/UI-Source-Code
   pip install -r requirements.txt
   python app.py
   ```

4. Open http://127.0.0.1:5000 in a browser.

The interface supports viewing, inserting and deleting members, memberships, trainers, fitness sessions and bookings. Every change is written to the MySQL database.
