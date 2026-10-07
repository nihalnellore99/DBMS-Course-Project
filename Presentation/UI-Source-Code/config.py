"""Database settings. Change DB_PASSWORD to your own MySQL root password."""
import os

DB_HOST = os.environ.get("GYM_DB_HOST", "localhost")
DB_PORT = int(os.environ.get("GYM_DB_PORT", "3306"))
DB_USER = os.environ.get("GYM_DB_USER", "root")
DB_PASSWORD = os.environ.get("GYM_DB_PASSWORD", "Nihal1234!@#$")     # <-- put your MySQL password here
DB_NAME = os.environ.get("GYM_DB_NAME", "gym_management")
