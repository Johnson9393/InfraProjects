import boto3
import os
import json

# print("===================================")
# print("File Scanner Application Started")
# print("===================================")

# print("Creating SQS Client...")

# sqs = boto3.client("sqs", region_name="us-east-1")

# print("SQS Client Created Successfully")

# response = sqs.list_queues()

# print(response)

# ====================================================================#
# SQS Helper functions 
# =================================================================== #

#SQS helper functions
# Create sqs client
# receive messages from sqs
# delete test event message

def create_sqs_client():
    print("Creating SQS Client...")
    region = os.getenv("AWS_REGION")

    return boto3.client("sqs", region_name=region)

def receive_messages(sqs, queue_url):
    print("checking for messages...")

    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=10
    )

    return response

def delete_message(sqs, queue_url, receipt_handle):
    print("Deleting message....")

    sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)

    print("Message deleted successfully")

# ====================================================================#
# S3 Helper functions
# =================================================================== #

def create_s3_client():
    print("Creating S3 Client...")
    region = os.getenv("AWS_REGION")

    return boto3.client("s3", region_name=region)

def download_file(s3, bucket_name, object_key):
    print("Downloading file...")

    s3.download_file(
        Bucket=bucket_name,
        Key=object_key,
        Filename=object_key
    )

    print("File downloaded successfully.")


def main():
    print("===================================")
    print("File Scanner Application Started")
    print("===================================")

    sqs = create_sqs_client()
    queue_url = os.getenv("QUEUE_URL")

    print(f"Queue URL: {queue_url}")
    print("SQS Client Created Successfully")

    response = receive_messages(sqs, queue_url)
    # print(response)
    messages = response.get("Messages", [])

    if not messages:
        print("No messages found.")
        return

    message = messages[0]
    receipt_handle = message["ReceiptHandle"]

    body = json.loads(message["Body"])

    if "Records" not in body:
        print("Received S3 Test Event. Deleting it...")
        delete_message(sqs, queue_url, receipt_handle)
        return
    
    #print(body)
    record = body["Records"][0]
    bucket_name = record["s3"]["bucket"]["name"]
    object_key = record["s3"]["object"]["key"]

    print(f"Bucket Name : {bucket_name}")
    print(f"Object Key  : {object_key}")

    s3 = create_s3_client()
    download_file(s3, bucket_name, object_key)

if __name__ == "__main__":
    main()