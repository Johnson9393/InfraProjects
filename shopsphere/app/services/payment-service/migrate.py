import os
import time
from pathlib import Path

import psycopg
from database import read_host_active


def split_sql(script):
    statements = []
    current = []
    for line in script.splitlines():
        stripped = line.strip()
        if stripped.startswith('--'):
            continue
        current.append(line)
        if stripped.endswith(';'):
            statement = '\n'.join(current).strip().rstrip(';').strip()
            if statement:
                statements.append(statement)
            current = []
    rest = '\n'.join(current).strip().rstrip(';').strip()
    if rest:
        statements.append(rest)
    return statements


def connect():
    last_error = None
    for attempt in range(1, 6):
        try:
            return psycopg.connect(
                host=os.getenv('PAYMENT_DB_HOST', 'localhost'),
                port=os.getenv('PAYMENT_DB_PORT', '5432'),
                user=os.getenv('PAYMENT_DB_USER', 'ecommerce_user'),
                password=os.getenv('PAYMENT_DB_PASSWORD', 'secure_password_123'),
                dbname=os.getenv('PAYMENT_DB_NAME', 'payments'),
                sslmode=os.getenv('PAYMENT_DB_SSLMODE', 'disable'),
            )
        except psycopg.Error as exc:
            last_error = exc
            print(f'database connection failed ({attempt}/5): {exc}')
            time.sleep(5)
    raise last_error


def apply_migrations(connection):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version text PRIMARY KEY,
                applied_at timestamptz NOT NULL DEFAULT now()
            )
            """
        )
    connection.commit()

    migration_dir = Path(__file__).resolve().parent / 'migrations'
    migrations = sorted(migration_dir.glob('*.sql'))
    for path in migrations:
        version = path.stem
        with connection.cursor() as cursor:
            cursor.execute(
                'SELECT COUNT(*) FROM schema_migrations WHERE version = %s',
                (version,),
            )
            count = cursor.fetchone()[0]
        if count:
            print(f'migration already applied: {version}')
            continue

        statements = split_sql(path.read_text())
        try:
            with connection.cursor() as cursor:
                for statement in statements:
                    cursor.execute(statement)
                cursor.execute(
                    'INSERT INTO schema_migrations (version) VALUES (%s)',
                    (version,),
                )
            connection.commit()
            print(f'migration applied: {version}')
        except Exception:
            connection.rollback()
            raise


def main():
    if read_host_active():
        print('PAYMENT_DB_READ_HOST is set; payment reads and writes stay on the writer')
    connection = connect()
    try:
        apply_migrations(connection)
    finally:
        connection.close()


if __name__ == '__main__':
    main()
