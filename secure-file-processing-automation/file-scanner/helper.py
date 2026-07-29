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

def get_clean_bucket():
    """Returns the clean bucket name."""

    print("Reading Clean Bucket Name...")

    return os.getenv("CLEAN_BUCKET")


def get_quarantine_bucket():
    """Returns the quarantine bucket name."""

    print("Reading Quarantine Bucket Name...")

    return os.getenv("QUARANTINE_BUCKET")

def get_topic_arn():
    """Returns the SNS topic ARN."""

    print("Reading SNS Topic ARN...")

    return os.getenv("TOPIC_ARN")