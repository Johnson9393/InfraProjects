# README_Troubleshooting.md

# Lambda Deployment Troubleshooting Guide

## Overview

This document captures all the issues encountered while deploying the Lambda Transaction Processor and the steps taken to resolve them.

The purpose of this document is to help reproduce the deployment without repeating the same mistakes and to understand the reasoning behind each fix.

---

# Issue 1 - Incorrect Lambda Deployment Package Structure

## Problem

Initially, the deployment package was uploaded exactly as it existed in the local project.

The ZIP contained:

serverless.zip

    transaction-processor/
        main.py
        db.py
        requirements.txt

Lambda could not locate the handler.

## Root Cause

Lambda expects the handler file to be present at the root of the deployment package.

Instead, the entire project folder was zipped.

## Resolution

Create the ZIP from inside the project directory.

Correct structure:

lambda.zip

    main.py
    db.py
    requirements.txt
    ...

The handler can now be resolved correctly.

---

# Issue 2 - Missing Python Dependencies

## Problem

The uploaded ZIP only contained the application source code.

It did not contain external Python libraries.

Lambda failed while importing psycopg.

## Root Cause

requirements.txt only lists dependencies.

Lambda does not install dependencies automatically.

Everything must already exist inside the deployment package.

## Resolution

Create a package directory.

Install dependencies into it.

Copy the application source code.

Commands:

rm -rf package lambda.zip

mkdir package

docker run --rm \
--entrypoint /bin/sh \
-v "$PWD":/var/task \
public.ecr.aws/lambda/python:3.12 \
-c "pip install -r requirements.txt -t package && cp *.py package/ && cp test_event.json package/"

cd package

zip -r ../lambda.zip .

cd ..

Upload the new ZIP.

---

# Issue 3 - psycopg Native Library Error

## Error

Runtime.ImportModuleError

Unable to import module 'main'

No pq wrapper available

## Investigation

We inspected the generated package.

The psycopg shared library was:

pq.cpython-312-aarch64-linux-gnu.so

The Lambda runtime architecture was:

x86_64

The compiled library architecture and Lambda runtime architecture did not match.

## Root Cause

The package was built on an Apple Silicon Mac.

Docker generated ARM64 binaries.

Lambda was configured for x86_64.

Compiled native libraries cannot run on a different CPU architecture.

## Resolution

Instead of rebuilding the package for x86_64, the Lambda architecture was changed to ARM64.

After the architecture matched, psycopg loaded successfully.

---

# Issue 4 - Missing S3 Permissions

## Error

AccessDenied

s3:GetObject

Later

AccessDenied

s3:ListBucket

## Root Cause

The Lambda execution role only contained the basic execution policies.

It had no permission to read objects from the S3 bucket.

## Resolution

Added an inline IAM policy.

Permissions added:

- s3:GetObject
- s3:ListBucket

After updating the IAM Role, Lambda successfully accessed S3.

---

# Issue 5 - Object Does Not Exist

## Error

NoSuchKey

## Root Cause

The test event referenced an object that did not exist inside the bucket.

Infrastructure was working correctly.

The requested file simply was not present.

## Resolution

Upload a CSV into the configured S3 bucket.

Update the test event with the correct object key.

Lambda successfully read the file.

---

# Issue 6 - Database Connection Failure

## Error

connection failed

server closed the connection unexpectedly

## Investigation

Verified:

- Environment Variables
- Database Host
- Database Port

Everything was correct.

Next, the RDS Security Group was inspected.

Lambda Security Group was missing.

## Root Cause

Lambda was deployed inside the VPC.

However, RDS was not allowing inbound traffic from Lambda.

The database rejected the network connection.

## Resolution

Added the Lambda Security Group to the RDS Security Group.

Rule:

Type:

PostgreSQL

Port:

5432

Source:

Lambda Security Group

Database connectivity was immediately restored.

---

# Final Validation

After all fixes were applied:

Application

↓

S3 Upload

↓

Lambda Trigger

↓

CSV Read

↓

PostgreSQL Connection

↓

Database Insert

↓

Success Response

Lambda Output

{
    "statusCode": 200,
    "body": "CSV processed successfully"
}

---

# Lessons Learned

• Lambda deployment packages must contain both application code and installed dependencies.

• Native Python libraries (such as psycopg) must be compiled for the same operating system and CPU architecture used by Lambda.

• ARM64 packages require ARM64 Lambda functions.

• RDS deployed inside a private subnet requires Lambda to run inside the same VPC.

• Lambda Security Group must be allowed by the RDS Security Group.

• IAM permissions should be granted using the principle of least privilege.

• Uploading source code alone is not sufficient for Lambda deployments when native dependencies are involved.

• Validate infrastructure one layer at a time:
  1. Lambda imports
  2. IAM permissions
  3. S3 access
  4. Network connectivity
  5. Database connectivity
  6. Business logic

Following this approach significantly reduces debugging time.