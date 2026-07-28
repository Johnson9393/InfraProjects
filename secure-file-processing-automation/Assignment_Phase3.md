# Assignment – Phase 3: Amazon S3 Integration

## Objective

In this phase, we integrated Amazon S3 with our malware scanner.

The goal is to consume an S3 ObjectCreated event from SQS, extract the bucket name and object key, download the uploaded file into the scanner container, and verify that the file has been downloaded successfully.

---

# Architecture

```text
User Upload
     │
     ▼
Landing S3 Bucket
     │
     ▼
S3 Event Notification
     │
     ▼
Amazon SQS
     │
     ▼
Docker Container
     │
     ▼
Receive SQS Message
     │
     ▼
Parse JSON
     │
     ▼
Extract Bucket Name
Extract Object Key
     │
     ▼
Create S3 Client
     │
     ▼
Download File
     │
     ▼
Verify Download
```

---

# Concepts Covered

## 1. json.loads() vs json.load()

### json.loads()

Used when the input is a JSON string.

Example:

```python
body = json.loads(message["Body"])
```

SQS returns the message body as a JSON string, therefore we convert it into a Python dictionary using `json.loads()`.

---

### json.load()

Used when reading JSON directly from a file.

Example:

```python
with open("config.json") as file:
    config = json.load(file)
```

---

### Memory Trick

| Function | Used For |
|----------|----------|
| json.loads() | JSON String → Python Object |
| json.load() | JSON File → Python Object |

---

## 2. Dictionary get()

Instead of

```python
messages = response["Messages"]
```

we used

```python
messages = response.get("Messages", [])
```

### Why?

If the queue is empty, AWS does not return the `Messages` key.

Using

```python
response["Messages"]
```

throws

```text
KeyError: 'Messages'
```

Using

```python
response.get("Messages", [])
```

returns

```python
[]
```

which allows us to safely check

```python
if not messages:
    return
```

### Rule

Use

```python
dict.get()
```

when a key may not exist.

Use

```python
dict["key"]
```

only when the key is guaranteed to exist.

---

# AWS Authentication inside Docker

The application runs inside a Docker container.

Instead of hardcoding AWS credentials, AWS SSO credentials from the local machine are mounted into the container.

Docker command:

```bash
docker run --rm \
-v ~/.aws:/root/.aws \
-e AWS_PROFILE=dojo-dev-admin \
-e AWS_REGION=us-east-1 \
-e QUEUE_URL=https://sqs.us-east-1.amazonaws.com/<account-id>/file-scan-queue-dev \
file-scanner:1.0
```

Explanation:

| Option | Purpose |
|---------|----------|
| -v ~/.aws:/root/.aws | Mount AWS credentials and SSO cache |
| AWS_PROFILE | AWS SSO Profile |
| AWS_REGION | AWS Region |
| QUEUE_URL | Queue URL |
| file-scanner:1.0 | Docker Image |

> Initially the AWS folder was mounted as read-only which caused AWS SSO token refresh to fail. The mount was later changed to read-write.

---

# Functions Implemented

## Create SQS Client

```python
create_sqs_client()
```

Purpose

- Creates the Amazon SQS client.

---

## Receive Messages

```python
receive_messages()
```

Purpose

- Long polling
- Reads one message from SQS.

---

## Delete Message

```python
delete_message()
```

Purpose

Deletes the processed SQS message.

---

## Create S3 Client

```python
create_s3_client()
```

Purpose

Creates the Amazon S3 client.

Implementation

```python
def create_s3_client():
    region = os.getenv("AWS_REGION")
    return boto3.client(
        "s3",
        region_name=region
    )
```

---

## Download File

```python
download_file()
```

Purpose

Downloads the uploaded object from Amazon S3.

Implementation

```python
def download_file(s3, bucket_name, object_key):
    s3.download_file(
        Bucket=bucket_name,
        Key=object_key,
        Filename=object_key
    )
```

---

# Flow Implemented

Application starts.

↓

Create SQS Client.

↓

Receive SQS Message.

↓

Parse JSON.

↓

Ignore S3 Test Event.

↓

Delete Test Event.

↓

Extract

- Bucket Name
- Object Key

↓

Create S3 Client.

↓

Download the object.

↓

Verify download.

---

# Testing

## Upload File

Upload a file into the Landing Bucket.

Example

```
docker_questions.csv
```

---

## Run Docker

```bash
docker run --rm \
-v ~/.aws:/root/.aws \
-e AWS_PROFILE=dojo-dev-admin \
-e AWS_REGION=us-east-1 \
-e QUEUE_URL=https://sqs.us-east-1.amazonaws.com/<account-id>/file-scan-queue-dev \
file-scanner:1.0
```

Expected Output

```text
Creating SQS Client...

checking for messages...

Bucket Name : file-scan-landing-dev

Object Key : docker_questions.csv

Creating S3 Client...

Downloading file...

File downloaded successfully.
```

---

## Verify Download

Run the container interactively.

```bash
docker run -it \
-v ~/.aws:/root/.aws \
-e AWS_PROFILE=dojo-dev-admin \
-e AWS_REGION=us-east-1 \
-e QUEUE_URL=https://sqs.us-east-1.amazonaws.com/<account-id>/file-scan-queue-dev \
file-scanner:1.0 \
/bin/bash
```

Inside the container

```bash
pwd
```

Expected

```text
/app
```

Run

```bash
python app.py
```

Verify

```bash
ls -l
```

Expected

```text
docker_questions.csv
```

This confirms the object has been successfully downloaded from Amazon S3 into the container.

---

# Phase 3 Completion Checklist

- [x] Create SQS Client
- [x] Receive SQS Message
- [x] Parse JSON
- [x] Ignore S3 Test Event
- [x] Delete Test Event
- [x] Extract Bucket Name
- [x] Extract Object Key
- [x] Create S3 Client
- [x] Download File
- [x] Verify Download inside Docker

---

# Next Phase

Phase 4 – ClamAV Integration

We will implement:

- Install/update ClamAV virus definitions
- Scan downloaded file
- Read scan result
- Determine CLEAN or INFECTED
- Continue the malware scanner workflow