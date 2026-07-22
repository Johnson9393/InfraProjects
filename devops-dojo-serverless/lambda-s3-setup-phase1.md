# AWS Serverless File Processing Pipeline using S3, Lambda, Secrets Manager and PostgreSQL

## Project Objective

The objective of this project is to build a secure, production-style serverless file processing pipeline on AWS.

The application is designed to automatically process CSV files uploaded to an Amazon S3 bucket without requiring any server management. Whenever a new CSV file is uploaded into the **inbound** folder of the S3 bucket, Amazon S3 generates an event notification that invokes an AWS Lambda function.

The Lambda function reads the uploaded file, validates its contents, securely retrieves the PostgreSQL database credentials from AWS Secrets Manager, establishes a connection to an Amazon RDS PostgreSQL database running inside a private VPC, and stores the transaction details into the database.

The primary goal of this implementation is to understand how multiple AWS services communicate with each other in a real-world production architecture while following security best practices such as using IAM Roles, AWS Secrets Manager, VPC networking, Lambda Layers, and least privilege access.

This project also demonstrates event-driven architecture where no manual execution is required after uploading the file. Everything happens automatically through AWS managed services.

---

# Architecture

```
                    CSV Upload
                         │
                         ▼
              Amazon S3 Bucket (Inbound)
                         │
          Object Created Event Notification
                         │
                         ▼
                 AWS Lambda Function
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
 Read CSV File    AWS Secrets Manager    CloudWatch Logs
        │                │
        │                ▼
        │      PostgreSQL Connection String
        │
        ▼
 Amazon RDS PostgreSQL Database
```

---

# Technologies Used

| Service | Purpose |
|----------|----------|
| Amazon S3 | Stores uploaded CSV files |
| AWS Lambda | Processes uploaded files |
| AWS Secrets Manager | Securely stores database credentials |
| Amazon RDS PostgreSQL | Stores transaction information |
| IAM | Authentication and Authorization |
| VPC | Secure private network connectivity |
| Security Groups | Controls network access |
| CloudWatch | Logging and Monitoring |
| Docker | Build Lambda Layer compatible with AWS |
| Python 3.13 | Lambda Runtime |
| psycopg | PostgreSQL Driver |

---

# Project Flow

The complete flow of the application is shown below.

1. User uploads a CSV file into the **inbound** folder inside the S3 bucket.

2. Amazon S3 automatically generates an Object Created event.

3. The event notification invokes the Lambda function.

4. Lambda downloads the uploaded CSV file.

5. Lambda validates the file.

6. Lambda retrieves the PostgreSQL connection string securely from AWS Secrets Manager.

7. Lambda establishes a connection with PostgreSQL running inside Amazon RDS.

8. Lambda inserts transaction details into the database.

9. CloudWatch stores all execution logs.

10. Depending on the processing result, the transaction status becomes either SUCCESS or FAILED.

> **Note:** At the time of writing this README, successful files are still present inside the `inbound` folder. The next enhancement is to move successful files into the `archive` folder and failed files into the `error` folder after processing.

---

# Why We Chose This Architecture

Instead of running a continuously available EC2 instance to process uploaded files, we chose an event-driven serverless architecture.

Advantages of this approach:

- No server management.
- Pay only when Lambda executes.
- Automatically scales based on incoming files.
- Less operational overhead.
- Better security using IAM Roles and Secrets Manager.
- Production-ready AWS architecture.

---

# Existing Infrastructure

Before starting the Lambda implementation, the infrastructure had already been provisioned using Terraform.

The following resources were already available.

- VPC
- Private Subnets
- Public Subnets
- Route Tables
- Internet Gateway
- NAT Gateway
- Amazon RDS PostgreSQL
- Amazon S3 Bucket
- Security Groups
- IAM Roles
- Secrets Manager Secret

Therefore, our objective was **only to recreate the Lambda function from scratch and integrate it with the existing infrastructure.**

---

# Directory Structure

Inside the project repository, navigate to the following directory.

```

project-root/
│
├── app/
├── infra/
└── serverless/
├── main.py
├── db.py
├── requirements.txt
└── test_event.json

```

All Lambda related work will be performed inside the **serverless** directory.

Navigate into the directory.

```bash
cd serverless
```

Verify your current working directory.

```bash
pwd
```

This directory contains the Lambda source code.

- **main.py** – Main Lambda handler.
- **db.py** – Database connection helper.
- **requirements.txt** – Python dependencies.
- **test_event.json** – Sample Lambda test event.

---

# Understanding the Initial Problem

Initially, the Lambda package contained external Python libraries along with the application code.

Although this approach works for small applications, it becomes difficult to maintain because every deployment requires uploading all third-party libraries again.

A better production practice is to separate the application code from the dependencies.

AWS provides **Lambda Layers** exactly for this purpose.

Therefore, we decided to move all third-party libraries into a dedicated Lambda Layer while keeping the deployment package lightweight.

Advantages of using Lambda Layers:

- Smaller deployment package.
- Faster deployments.
- Reusable across multiple Lambda functions.
- Easier dependency upgrades.
- Production best practice.

---

