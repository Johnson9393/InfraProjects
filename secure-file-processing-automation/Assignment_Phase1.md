# File Scanning Assignment Phase 1

## Objective

Build the initial event-driven pipeline for a malware scanning system using AWS services.

In this phase, we are setting up the infrastructure required to receive file upload events. Whenever a file is uploaded to an Amazon S3 bucket, Amazon S3 will send an event notification to an Amazon SQS queue. The SQS queue will later be consumed by an ECS-based Python application that performs malware scanning.

At the end of this phase, the following flow is established:

```text
Upload File
      │
      ▼
Amazon S3
      │
      ▼
S3 Event Notification
      │
      ▼
Amazon SQS
```

---

# Step 1 - Create the Landing S3 Bucket

## Navigation

```text
AWS Console
    ↓
Amazon S3
    ↓
Create Bucket
```

## Configuration

| Setting | Value |
|----------|-------|
| Bucket Name | file-scan-landing-dev |
| AWS Region | us-east-1 |
| Object Ownership | ACLs Disabled (Bucket owner enforced) |
| Block Public Access | Enabled |
| Bucket Versioning | Enabled |
| Default Encryption | Server-side encryption with Amazon S3 managed keys (SSE-S3) |
| Remaining Settings | Default |

Click **Create Bucket**.

---

## Why do we need this bucket?

This bucket acts as the landing location where users upload files.

At this stage, the bucket is only responsible for storing uploaded files.

Later, our ECS application will download files from this bucket and perform malware scanning.

---

# Step 2 - Create the Amazon SQS Queue

## What is Amazon SQS?

Amazon Simple Queue Service (SQS) is a fully managed message queue.

Instead of directly invoking another application, AWS services can place a message into a queue. The consumer application processes these messages whenever it is ready.

For this project:

- Amazon S3 stores the uploaded file.
- Amazon S3 sends a notification message to Amazon SQS.
- Our ECS application will later read messages from SQS and scan the corresponding file.

---

## Navigation

```text
AWS Console
    ↓
Amazon SQS
    ↓
Create Queue
```

## Configuration

| Setting | Value |
|----------|-------|
| Queue Type | Standard |
| Queue Name | file-scan-queue-dev |
| Visibility Timeout | Default (30 Seconds) |
| Message Retention | Default (4 Days) |
| Delivery Delay | Default |
| Maximum Message Size | Default (256 KB) |
| Receive Message Wait Time | Default |
| Encryption | SSE-SQS |
| Dead Letter Queue | Not Configured |

Click **Create Queue**.

---

## Why Standard Queue?

The malware scanning application does not require messages to be processed in any specific order.

Our primary requirements are:

- High throughput
- Automatic scaling
- Reliable message delivery

Therefore, a Standard Queue is the appropriate choice.

---

# Step 3 - Allow Amazon S3 to Send Messages to Amazon SQS

By default, Amazon SQS does not accept messages from other AWS services.

Therefore, we need to explicitly grant permission to Amazon S3 using a **Resource-Based Policy**.

---

## Navigation

```text
Amazon SQS
    ↓
file-scan-queue-dev
    ↓
Access Policy
    ↓
Edit
```

Add the following policy (replace the AWS Account ID with your own account ID):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ToSendMessages",
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:<ACCOUNT_ID>:file-scan-queue-dev",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:s3:::file-scan-landing-dev"
        }
      }
    }
  ]
}
```

Save the policy.

---

## Why is this policy required?

This policy allows Amazon S3 to send messages to the SQS queue.

Without this permission:

```text
Amazon S3
      │
      ▼
Amazon SQS
      ❌ Access Denied
```

After adding the policy:

```text
Amazon S3
      │
      ▼
Amazon SQS
      ✅ Message Accepted
```

---

# Step 4 - Configure S3 Event Notification

Now we configure the S3 bucket so that every file upload automatically generates a notification message.

---

## Navigation

```text
Amazon S3
    ↓
file-scan-landing-dev
    ↓
Properties
    ↓
Event Notifications
    ↓
Create Event Notification
```

---

## Configuration

| Setting | Value |
|----------|-------|
| Event Notification Name | landing-file-upload-event |
| Prefix | Leave Empty |
| Suffix | Leave Empty |
| Event Type | Object Creation → All Object Create Events |
| Destination | Amazon SQS Queue |
| Queue | file-scan-queue-dev |

Click **Save Changes**.

---

## Why Event Notification?

An Event Notification tells Amazon S3 what action should be performed whenever a specific event occurs.

In our project:

- Event = Object Created
- Action = Send a notification message to Amazon SQS

---

# Step 5 - Verify the Integration

Upload any file into the S3 bucket.

Example:

```text
docker_questions.csv
```

After uploading the file:

Navigate to:

```text
Amazon SQS
    ↓
file-scan-queue-dev
    ↓
Send and Receive Messages
    ↓
Poll for Messages
```

You should observe two messages:

### 1. S3 Test Event

```json
{
  "Service": "Amazon S3",
  "Event": "s3:TestEvent"
}
```

This message is automatically generated when the event notification is created. It confirms that Amazon S3 can successfully communicate with Amazon SQS.

---

### 2. Actual Object Creation Event

The second message contains details about the uploaded object.

Example:

```json
{
  "Records": [
    {
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {
          "name": "file-scan-landing-dev"
        },
        "object": {
          "key": "docker_questions.csv"
        }
      }
    }
  ]
}
```

This is the message that our ECS application will process in the next phase.

---

# Current Architecture

```text
                Upload File
                     │
                     ▼
      +-----------------------------+
      | Amazon S3 Landing Bucket    |
      | file-scan-landing-dev       |
      +-----------------------------+
                     │
      Object Created Event
                     │
                     ▼
      +-----------------------------+
      | S3 Event Notification       |
      +-----------------------------+
                     │
                     ▼
      +-----------------------------+
      | Amazon SQS                  |
      | file-scan-queue-dev         |
      +-----------------------------+
```