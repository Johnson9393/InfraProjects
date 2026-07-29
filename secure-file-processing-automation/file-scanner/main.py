"""
Main application workflow for the malware scanner.
"""

import json
from urllib.parse import unquote_plus

from helper import get_queue_url
from aws_helper import (
    create_sqs_client,
    create_s3_client,
    receive_messages,
    download_file,
    delete_message,
)
from clamav_helper import scan_file


def main():
    """Starts the malware scanner."""

    print("===================================")
    print("Starting File Scanner Application")
    print("===================================")

    sqs = create_sqs_client()
    s3 = create_s3_client()

    queue_url = get_queue_url()

    print("AWS clients created successfully.")

    while True:

        response = receive_messages(sqs, queue_url)
        messages = response.get("Messages", [])

        if not messages:
            print("No messages found. Waiting...")
            continue

        message = messages[0]
        receipt_handle = message["ReceiptHandle"]

        body = json.loads(message["Body"])

        # Ignore S3 Test Event
        if "Records" not in body:
            print("Received S3 Test Event.")

            delete_message(
                sqs,
                queue_url,
                receipt_handle
            )

            continue

        record = body["Records"][0]

        bucket_name = record["s3"]["bucket"]["name"]
        object_key = unquote_plus(record["s3"]["object"]["key"])

        print(f"Bucket Name : {bucket_name}")
        print(f"Object Key  : {object_key}")

        local_file_path = download_file(
            s3,
            bucket_name,
            object_key
        )

        try:
            scan_file(local_file_path)

            delete_message(
                sqs=sqs,
                queue_url=queue_url,
                receipt_handle=receipt_handle
            )

        except Exception as e:
            print(f"Scanning failed: {e}")


if __name__ == "__main__":
    main()