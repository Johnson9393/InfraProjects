# Assignment Phase 4 – Dockerized Malware Scanner Worker

## Objective

In this phase, we built the malware scanning worker that continuously listens for S3 upload events from Amazon SQS, downloads the uploaded file from Amazon S3, scans it using ClamAV, and deletes the processed SQS message.

The application runs inside a Docker container and is designed to be deployed later on Amazon ECS Fargate.

---

# High Level Architecture

```
                +----------------------+
                |   Amazon S3 Bucket   |
                +----------+-----------+
                           |
                    Object Uploaded
                           |
                           v
                +----------------------+
                |  S3 Event Notification|
                +----------+-----------+
                           |
                           v
                +----------------------+
                |     Amazon SQS       |
                +----------+-----------+
                           |
                     Poll Messages
                           |
                           v
                +----------------------+
                | Docker Scanner Worker|
                | (Python + ClamAV)    |
                +----------+-----------+
                           |
          +----------------+----------------+
          |                                 |
          v                                 v
 Download file from S3              Scan using ClamAV
          |
          v
 Delete processed SQS Message
```

---

# Project Goal

The scanner continuously waits for new files.

Whenever a user uploads a file into the S3 bucket:

- Amazon S3 sends an event notification.
- The notification is delivered to Amazon SQS.
- The Python worker receives the message.
- The file is downloaded locally.
- ClamAV scans the file.
- The processed SQS message is deleted.
- The worker immediately starts waiting for the next upload.

This makes the worker run continuously without requiring a restart.

---

# Files Created / Updated

```
file-scanner/
│
├── Dockerfile
├── entrypoint.sh
├── requirements.txt
├── app.py
└── .dockerignore
```

---

# Dockerfile

## Purpose

The Dockerfile creates a lightweight container image containing:

- Python runtime
- Python dependencies
- ClamAV
- Freshclam
- Application source code

It also configures the container to execute `entrypoint.sh` whenever the container starts.

---

# entrypoint.sh

## Purpose

The entrypoint is responsible for preparing the malware scanner before the Python application starts.

### Responsibilities

### 1. Create runtime directories

```
/var/run/clamav
/var/log/clamav
```

These directories are required by ClamAV during runtime.

---

### 2. Set permissions

Ownership is assigned to the `clamav` user.

```
chown -R clamav:clamav
```

This allows ClamAV to create its socket and access the virus database.

---

### 3. Download Virus Database

The script checks whether the virus definitions already exist.

If they do not exist,

```
freshclam
```

downloads the latest signatures.

This happens only during the first container startup.

---

### 4. Start ClamAV

The daemon is started in the background.

```
clamd --foreground >/dev/null 2>&1 &
```

The foreground mode keeps the process alive while background execution allows the shell script to continue.

Output is redirected to keep container logs clean.

---

### 5. Wait for ClamAV Socket

The script waits until

```
/var/run/clamav/clamd.ctl
```

is created.

Only after the socket becomes available does the Python application start.

This guarantees that ClamAV is fully ready before scanning requests arrive.

---

### 6. Start Python Worker

```
python -u app.py
```

The `-u` option enables unbuffered logging so container logs appear immediately.

---

# Python Application

The application was structured into reusable helper functions.

---

## create_sqs_client()

Creates an Amazon SQS client using boto3.

Uses

```
AWS_REGION
```

from environment variables.

---

## receive_messages()

Continuously polls SQS using long polling.

```
WaitTimeSeconds = 20
```

Long polling reduces unnecessary API calls and lowers AWS costs by waiting for messages instead of repeatedly making empty requests.

---

## delete_message()

Deletes the processed SQS message after successful processing.

This prevents the same file from being scanned repeatedly.

---

## create_s3_client()

Creates an Amazon S3 client.

---

## download_file()

Downloads the uploaded object into

```
/tmp/scanner
```

inside the container.

Only the filename is stored locally.

---

## scan_file()

Creates a ClamAV socket connection.

```
ClamdUnixSocket()
```

The downloaded file is scanned.

The function returns the ClamAV scan result.

Example:

```
('OK', None)

or

('FOUND', 'Eicar-Signature')
```

---

# main()

The application entry point performs the following workflow.

```
Create SQS Client

↓

Create S3 Client

↓

Read Queue URL

↓

Infinite Loop

↓

Receive SQS Message

↓

Ignore S3 Test Events

↓

Extract Bucket Name

↓

Extract Object Key

↓

Download File

↓

Scan File

↓

Delete SQS Message

↓

Wait for Next Upload
```

---

# Long Polling

Instead of continuously calling Amazon SQS,

the worker uses

```
WaitTimeSeconds = 20
```

This allows Amazon SQS to keep the connection open until either:

- a message arrives
- or 20 seconds expires

Benefits

- Lower API calls
- Lower AWS cost
- Faster message processing

---

# Environment Variables

The container uses the following variables.

```
AWS_PROFILE

AWS_REGION

QUEUE_URL
```

These values are passed while starting the container.

---

# Running the Container

Build the Docker image

```bash
docker build -t file-scanner:1.0 .
```

Run the scanner

```bash
docker run --rm \
-v ~/.aws:/root/.aws \
-e AWS_PROFILE=dojo-dev-admin \
-e AWS_REGION=us-east-1 \
-e QUEUE_URL=https://sqs.us-east-1.amazonaws.com/<account-id>/file-scan-queue-dev \
file-scanner:1.0
```

---

# Validation Performed

The following scenarios were successfully tested.

### Clean File

- Uploaded a normal file.
- File downloaded successfully.
- ClamAV returned

```
OK
```

- SQS message deleted successfully.

---

### Malware Detection

Uploaded the EICAR antivirus test file.

ClamAV successfully detected

```
FOUND
```

with

```
Eicar-Signature
```

confirming that malware detection is functioning correctly.

---

# Outcome

At the end of Phase 4, we have a continuously running malware scanner worker capable of:

- Listening for new S3 uploads through Amazon SQS
- Downloading uploaded files from Amazon S3
- Scanning files using ClamAV
- Detecting clean and infected files
- Deleting processed SQS messages
- Continuing to process future uploads without restarting the container

This completes the core scanning engine that will be extended in the next phase with S3 object tagging and notification capabilities.