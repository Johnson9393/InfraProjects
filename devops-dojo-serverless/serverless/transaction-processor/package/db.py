import os
import psycopg

#psycopg is used to connect to the PostgreSQL database. It is a PostgreSQL adapter for Python that allows you to interact with a PostgreSQL database using Python code. It provides a way to establish a connection, execute SQL queries, and retrieve results from the database.
DATABASE_URL = (
    f"postgresql://{os.environ['DB_USER']}:"
    f"{os.environ['DB_PASSWORD']}@"
    f"{os.environ['DB_HOST']}:"
    f"{os.environ.get('DB_PORT', '5432')}/"
    f"{os.environ['DB_NAME']}"
)


def get_db_connection():
    return psycopg.connect(DATABASE_URL)