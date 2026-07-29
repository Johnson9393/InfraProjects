"""
AWS helper functions for Amazon S3 and Amazon SQS operations.
"""

import os
import boto3

from helper import DOWNLOAD_DIR, get_region


# ====================================================================
# Amazon SQS Helper Functions
# ====================================================================

def create_sqs_client():
    """Creates and returns an Amazon SQS client."""

    print("Creating Amazon SQS Client...")

    return boto3.client(
        "sqs",
        region_name=get_region()
    )


def receive_messages(sqs, queue_url):
    """Receives messages from Amazon SQS using long polling."""

    print("Polling Amazon SQS for messages...")

    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=20
    )

    return response


def delete_message(sqs, queue_url, receipt_handle):
    """Deletes a processed message from Amazon SQS."""

    print("Deleting processed SQS message...")

    sqs.delete_message(
        QueueUrl=queue_url,
        ReceiptHandle=receipt_handle
    )

    print("SQS message deleted successfully.")


# ====================================================================
# Amazon S3 Helper Functions
# ====================================================================

def create_s3_client():
    """Creates and returns an Amazon S3 client."""

    print("Creating Amazon S3 Client...")

    return boto3.client(
        "s3",
        region_name=get_region()
    )


def download_file(s3, bucket_name, object_key):
    """Downloads an object from Amazon S3."""

    print(f"Downloading '{object_key}' from bucket '{bucket_name}'...")

    os.makedirs(DOWNLOAD_DIR, exist_ok=True)

    file_name = os.path.basename(object_key)
    local_file_path = os.path.join(DOWNLOAD_DIR, file_name)

    s3.download_file(
        Bucket=bucket_name,
        Key=object_key,
        Filename=local_file_path
    )

    print(f"File downloaded successfully: {local_file_path}")

    return local_file_path