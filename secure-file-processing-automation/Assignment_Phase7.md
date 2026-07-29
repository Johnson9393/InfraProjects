# Phase 7 – SNS Email Notifications

## Objective

In this phase, the malware scanner is enhanced to send an email notification after a file has been successfully processed.

Notifications are sent after:

- File scanning
- S3 object tagging
- File movement to the destination bucket

The email contains the scan result and the final destination of the file.

---

# Architecture

```text
                    +----------------------+
                    |  Landing Bucket      |
                    +----------+-----------+
                               |
                               ▼
                     S3 Event Notification
                               |
                               ▼
                          Amazon SQS
                               |
                               ▼
                     Python Malware Scanner
                               |
                +--------------+--------------+
                |                             |
                ▼                             ▼
        Scan Successful               Scan Infected
                |                             |
                ▼                             ▼
     Tag: scan-status=clean       Tag: scan-status=infected
                |                             |
                ▼                             ▼
      Move to Clean Bucket       Move to Quarantine Bucket
                |                             |
                +--------------+--------------+
                               |
                               ▼
                  Publish SNS Notification
                               |
                               ▼
                     Delete SQS Message
```

---

# AWS Resources

## SNS Topic

A Standard SNS Topic is created.

```
file-scan-notifications-dev
```

---

## Email Subscription

An Email subscription is attached to the topic.

```
Protocol : Email
Endpoint : your-email@example.com
```

The subscription must be confirmed before SNS can deliver emails.

---

# Changes Made

## 1. Added Topic ARN Helper

A new helper has been added to `helper.py`.

```python
def get_topic_arn():
    """Returns the SNS topic ARN."""

    print("Reading SNS Topic ARN...")

    return os.getenv("TOPIC_ARN")
```

This helper reads the SNS Topic ARN from an environment variable.

---

## 2. Added SNS Client

A reusable SNS client has been added to `aws_helper.py`.

```python
def create_sns_client():
    """Creates an SNS client."""

    print("Creating SNS client...")

    return boto3.client(
        "sns",
        region_name=get_region()
    )
```

---

## 3. Added SNS Publish Helper

A reusable helper has been added to publish notifications.

```python
def publish_sns_notification(
    sns_client,
    topic_arn,
    subject,
    message
):
    """Publishes a notification to an SNS topic."""

    print("Publishing SNS notification...")

    sns_client.publish(
        TopicArn=topic_arn,
        Subject=subject,
        Message=message
    )

    print("SNS notification published successfully.")
```

This helper uses the SNS `publish()` API to send an email notification.

---

## 4. Created SNS Client

The application now creates an SNS client during startup.

```python
sns_client = create_sns_client()
```

---

## 5. Read the Topic ARN

The Topic ARN is loaded from the environment.

```python
topic_arn = get_topic_arn()
```

---

## 6. Publish Notification

After the file is moved successfully, an SNS notification is published.

### Clean File

```python
subject = "File Scan Result"

message = (
    f"File Name : {object_key}\n"
    f"Status    : CLEAN\n"
    f"Bucket    : {destination_bucket}"
)
```

Example Email

```
Subject:
File Scan Result

File Name : report.pdf
Status    : CLEAN
Bucket    : file-scan-clean-dev
```

---

### Infected File

```python
threat_name = list(scan_result.values())[0][1]

subject = "Malware Detected"

message = (
    f"File Name : {object_key}\n"
    f"Status    : INFECTED\n"
    f"Threat    : {threat_name}\n"
    f"Bucket    : {destination_bucket}"
)
```

Example Email

```
Subject:
Malware Detected

File Name : eicar.txt
Status    : INFECTED
Threat    : Eicar-Signature
Bucket    : file-scan-quarantine-dev
```

---

## 7. Publish the Notification

```python
publish_sns_notification(
    sns_client,
    topic_arn,
    subject,
    message
)
```

The notification is sent only after:

- File downloaded successfully
- Scan completed successfully
- Object tagged successfully
- File moved successfully

---

# Docker Run Command

A new environment variable is added for the SNS Topic ARN.

```bash
docker run --rm \
-e AWS_REGION=us-east-1 \
-e QUEUE_URL=https://sqs.us-east-1.amazonaws.com/023192525105/file-scan-queue-dev \
-e CLEAN_BUCKET=file-scan-clean-dev \
-e QUARANTINE_BUCKET=file-scan-quarantine-dev \
-e TOPIC_ARN=arn:aws:sns:us-east-1:023192525105:file-scan-notifications-dev \
-v ~/.aws:/root/.aws \
-e AWS_PROFILE=dojo-dev-admin \
file-scanner:1.0
```

---

# Final Workflow

```text
Receive SQS Message
        │
        ▼
Download File
        │
        ▼
Scan using ClamAV
        │
        ▼
Determine Scan Status
        │
        ▼
Tag S3 Object
        │
        ▼
Move File
        │
        ├── Clean Bucket
        └── Quarantine Bucket
        │
        ▼
Publish SNS Notification
        │
        ▼
Delete SQS Message
```

---

# Testing

## Test 1 – Clean File

Upload a normal file.

Expected Result

- File scanned successfully
- Object tagged

```
scan-status = clean
```

- File moved to

```
file-scan-clean-dev
```

- Email received

```
Subject:
File Scan Result
```

Example

```
File Name : report.pdf
Status    : CLEAN
Bucket    : file-scan-clean-dev
```

---

## Test 2 – Infected File

Upload the EICAR test file.

Expected Result

- Malware detected
- Object tagged

```
scan-status = infected
```

- File moved to

```
file-scan-quarantine-dev
```

- Email received

```
Subject:
Malware Detected
```

Example

```
File Name : eicar.txt
Status    : INFECTED
Threat    : Eicar-Signature
Bucket    : file-scan-quarantine-dev
```

---

# Summary

Phase 7 integrates Amazon SNS into the malware scanning pipeline.

The application now:

- Creates an SNS client
- Reads the SNS Topic ARN from an environment variable
- Publishes an email notification after successful processing
- Sends separate notifications for clean and infected files
- Includes the malware signature for infected files
- Continues deleting the SQS message only after all processing steps complete

With this enhancement, administrators receive immediate notifications whenever a file is processed, improving visibility into the malware scanning workflow.