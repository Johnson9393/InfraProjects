# Lambda Deployment Setup Guide

## Overview

This document describes the complete setup performed **before testing
the Lambda with a CSV upload**. It serves as a deployment guide.

------------------------------------------------------------------------

# Architecture

    Application
          │
          ▼
     Amazon S3
          │
          ▼
     AWS Lambda
          │
          ▼
     Amazon RDS (PostgreSQL)

The Lambda function reads the uploaded CSV from S3, processes its
contents, and stores the records in PostgreSQL.

------------------------------------------------------------------------

# Step 1 -- Create the Lambda Function

Create a new Lambda function.

Configuration used:

-   Runtime: Python 3.12

-   Architecture: ARM64

-   Execution Role: Existing Role

-   Handler:

        main.lambda_handler

------------------------------------------------------------------------

# Step 2 -- Create Lambda Execution Role

Create an IAM Role for Lambda.

Attach AWS Managed Policies:

-   AWSLambdaBasicExecutionRole
-   AWSLambdaVPCAccessExecutionRole

Later, add an inline policy to allow access to the S3 bucket.

Example:

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::devopsdojo-transaction-files-dev"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::devopsdojo-transaction-files-dev/*"
    }
  ]
}
```

------------------------------------------------------------------------

# Step 3 -- Configure Lambda General Settings

Update General Configuration.

-   Memory: 512 MB
-   Timeout: 30 seconds

------------------------------------------------------------------------

# Step 4 -- Configure VPC

Attach Lambda to the same VPC as the RDS database.

Configuration:

-   Select project VPC
-   Select both private subnets
-   Attach Lambda Security Group

Reason:

The RDS instance is deployed inside private subnets. Lambda must also
run inside the VPC to communicate with it.

------------------------------------------------------------------------

# Step 5 -- Create Lambda Security Group

Create a dedicated Security Group for Lambda.

Inbound Rules

-   None

Outbound Rules

-   Allow All Traffic

------------------------------------------------------------------------

# Step 6 -- Update RDS Security Group

Allow PostgreSQL access from the Lambda Security Group.

Inbound Rule:

-   Type: PostgreSQL
-   Port: 5432
-   Source: Lambda Security Group

This allows Lambda to establish a database connection.

------------------------------------------------------------------------

# Step 7 -- Configure Environment Variables

Add the following variables to Lambda.

    DB_HOST
    DB_PORT
    DB_NAME
    DB_USER
    DB_PASSWORD

These values are used by `db.py` to create the PostgreSQL connection.

------------------------------------------------------------------------

# Step 8 -- Package the Lambda Function

Since the project contains native Python dependencies (`psycopg`),
package the application using Docker.

Clean previous package:

``` bash
rm -rf package lambda.zip
mkdir package
```

Install dependencies into the package directory:

``` bash
docker run --rm \
  --entrypoint /bin/sh \
  -v "$PWD":/var/task \
  public.ecr.aws/lambda/python:3.12 \
  -c "pip install -r requirements.txt -t package && cp *.py package/ && cp test_event.json package/"
```

Create deployment ZIP:

``` bash
cd package
zip -r ../lambda.zip .
cd ..
```

------------------------------------------------------------------------

# Step 9 -- Upload Deployment Package

Open the Lambda function.

Choose:

Code Source → Upload from → .zip file

Upload:

    lambda.zip

Deploy the updated code.

------------------------------------------------------------------------

# Step 10 -- Verify Lambda Configuration

Verify the following before testing.

-   Runtime: Python 3.12
-   Architecture: ARM64
-   Handler: main.lambda_handler
-   Execution Role attached
-   VPC configured
-   Private Subnets attached
-   Lambda Security Group attached
-   Environment Variables configured

------------------------------------------------------------------------

# Step 11 -- Prepare Test Data

Upload a CSV file into the configured S3 bucket.

The uploaded object will later be used by the Lambda function.

------------------------------------------------------------------------

# Step 12 -- Execute the Lambda

Run the Lambda using the configured S3 event (or test event that
references the uploaded object).

Expected Result:

``` json
{
  "statusCode": 200,
  "body": "CSV processed successfully"
}
```

------------------------------------------------------------------------

# Deployment Summary

The completed setup consists of:

-   Lambda Function
-   IAM Execution Role
-   S3 Permissions
-   VPC Configuration
-   Lambda Security Group
-   RDS Security Group
-   Environment Variables
-   Docker-based Packaging
-   ZIP Deployment
-   CSV Upload
-   Successful Lambda Execution

------------------------------------------------------------------------
