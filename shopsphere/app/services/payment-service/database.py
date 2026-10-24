import os
from urllib.parse import quote_plus

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


def database_uri():
    user = quote_plus(os.getenv('PAYMENT_DB_USER', 'ecommerce_user'))
    password = quote_plus(os.getenv('PAYMENT_DB_PASSWORD', 'secure_password_123'))
    host = os.getenv('PAYMENT_DB_HOST', 'localhost')
    port = os.getenv('PAYMENT_DB_PORT', '5432')
    name = os.getenv('PAYMENT_DB_NAME', 'payments')
    sslmode = os.getenv('PAYMENT_DB_SSLMODE', 'disable')
    return (
        f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"
        f"?sslmode={sslmode}"
    )


def engine_options():
    pool_size = int(os.getenv('PAYMENT_DB_POOL_SIZE', '5'))
    max_overflow = int(os.getenv('PAYMENT_DB_MAX_OVERFLOW', '10'))
    return {
        'pool_pre_ping': True,
        'pool_size': pool_size,
        'max_overflow': max_overflow,
        'pool_recycle': 1800,
    }


def read_host_active():
    write_host = os.getenv('PAYMENT_DB_HOST', 'localhost')
    read_host = os.getenv('PAYMENT_DB_READ_HOST', '')
    return bool(read_host) and read_host != write_host
