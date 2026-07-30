# README
# Replacing AWS Managed Policies with a Custom Least-Privilege IAM Policy

## Objective

During development, AWS managed policies were attached to the ECS Task Role for faster implementation.

Development Policies

```
AmazonS3FullAccess
AmazonSQSFullAccess
AmazonSNSFullAccess
```

These policies provide access to every S3 bucket, every SQS queue, and every SNS topic in the AWS account.

This is **not recommended for production** because it violates the Principle of Least Privilege.

The goal is to replace these AWS managed policies with a custom IAM policy that grants only the permissions required by the File Scanner application.

---

# Step 1 - Identify Required Permissions

First identify what the application actually does.

Our File Scanner performs the following operations.

## Amazon S3

Landing Bucket

- Download uploaded files
- (Optional) Delete uploaded files after processing

Clean Bucket

- Upload clean files

Quarantine Bucket

- Upload infected files

Object Metadata

- Add object tags after scanning

Bucket

- List bucket contents

---

## Amazon SQS

The worker continuously polls Amazon SQS.

Required operations

- Receive messages
- Delete processed messages
- Read queue attributes
- Change message visibility timeout

---

## Amazon SNS

The worker publishes scan results.

Required operation

- Publish messages

---

## CloudWatch Logs

If the application writes logs directly using the CloudWatch Logs API, allow:

- Create Log Stream
- Put Log Events

(If only ECS is writing container logs through the execution role, these permissions are not required on the task role.)

---

# Step 2 - Create a Custom IAM Policy

Navigation

```
IAM

↓

Policies

↓

Create Policy

↓

JSON
```

Replace the default JSON with a custom least-privilege policy.

---

# Step 3 - Required S3 Permissions

Landing Bucket

```
s3:GetObject
```

Purpose

Download uploaded files for malware scanning.

---

Landing Bucket

```
s3:DeleteObject
```

Purpose

Delete the original file after processing (only if your application performs this operation).

---

Clean Bucket

```
s3:PutObject
```

Purpose

Upload clean files.

---

Quarantine Bucket

```
s3:PutObject
```

Purpose

Upload infected files.

---

Object Tags

```
s3:PutObjectTagging
```

Purpose

Add scan status tags to S3 objects.

---

Bucket Permissions

```
s3:ListBucket
```

Purpose

Allow listing objects in the configured buckets.

---

# Step 4 - Required SQS Permissions

```
sqs:ReceiveMessage
```

Purpose

Receive messages from the queue.

---

```
sqs:DeleteMessage
```

Purpose

Delete the message after successful processing.

---

```
sqs:GetQueueAttributes
```

Purpose

Retrieve queue information such as message count and visibility timeout.

---

```
sqs:ChangeMessageVisibility
```

Purpose

Extend or modify message visibility while processing.

---

# Step 5 - Required SNS Permissions

```
sns:Publish
```

Purpose

Publish malware scan results.

---

# Step 6 - CloudWatch Logs Permissions (Optional)

If the application itself writes logs using the CloudWatch Logs API.

```
logs:CreateLogStream
```

```
logs:PutLogEvents
```

Purpose

Allow application logs to be written into CloudWatch.

---

# Step 7 - Create the Policy

Example Policy Name

```
file-scanner-task-policy
```

Description

```
Least privilege permissions for the ECS File Scanner application.
```

Click

```
Create Policy
```

---

# Step 8 - Attach the Policy to the ECS Task Role

Navigation

```
IAM

↓

Roles

↓

file-scanner-task-role
```

Click

```
Add Permissions

↓

Attach Policies
```

Select

```
file-scanner-task-policy
```

Attach the policy.

---

# Step 9 - Remove AWS Managed Policies

Detach

```
AmazonS3FullAccess
```

Detach

```
AmazonSQSFullAccess
```

Detach

```
AmazonSNSFullAccess
```

The ECS Task Role should now contain only

```
file-scanner-task-policy
```

---

# Final IAM Design

## ECS Task Execution Role

Keep

```
AmazonECSTaskExecutionRolePolicy
```

Purpose

- Pull Docker images from Amazon ECR
- Send container logs to CloudWatch
- Allow ECS infrastructure operations

---

## ECS Task Role

Keep only

```
file-scanner-task-policy
```

Purpose

- Read files from Amazon S3
- Move files between buckets
- Poll Amazon SQS
- Publish notifications to Amazon SNS

---

# Why Use a Custom IAM Policy?

Instead of giving the application unrestricted access to AWS services, the custom policy grants **only the permissions that are actually required**.

Benefits

- Improved security
- Reduced attack surface
- Follows AWS best practices
- Implements the Principle of Least Privilege
- Production-ready IAM design
- Easier security audits and compliance

---

# Summary

Removed AWS Managed Policies

```
AmazonS3FullAccess
AmazonSQSFullAccess
AmazonSNSFullAccess
```

Added Custom Policy

```
file-scanner-task-policy
```

Result

The ECS File Scanner application now has only the minimum permissions required to:

- Read files from S3
- Move files to clean/quarantine buckets
- Tag S3 objects
- Receive and delete SQS messages
- Publish SNS notifications

This follows AWS security best practices and is the recommended production approach.