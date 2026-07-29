"""
Common configuration used across the application.
"""

import os

DOWNLOAD_DIR = "/tmp/scanner"


def get_region():
    """Returns the AWS region."""

    print("Reading AWS Region...")

    return os.getenv("AWS_REGION")


def get_queue_url():
    """Returns the SQS Queue URL."""

    print("Reading Queue URL...")

    return os.getenv("QUEUE_URL")