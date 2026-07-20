# Event-Driven Quiz Processing System on AWS

## Introduction

This project is an enhanced version of my existing **DevOps Dojo** application, which is fully deployed on AWS using **Terraform**, **GitHub Actions**, **Docker**, **Amazon ECS Fargate**, and **Amazon RDS**.

The objective of this project is to redesign the existing file upload workflow by implementing an **event-driven serverless architecture** while reusing the existing infrastructure and CI/CD pipeline.

Instead of modifying the original project, a separate copy has been created to safely implement and validate the new architecture without affecting the existing application.

---

# Problem Statement

In the current application, uploaded quiz or interview question files are processed by the backend service and the data is written directly into Amazon RDS.

```text
User
   │
   ▼
Frontend
   │
   ▼
Backend (Amazon ECS)
   │
   ▼
Amazon RDS
```

Although this approach works, it tightly couples the application with database processing. As the size and number of uploaded files increase, the backend becomes responsible for file validation, parsing, and database insertion, making the application less scalable and harder to maintain.

---

# Proposed Solution

To overcome these limitations, the upload workflow will be redesigned using an event-driven architecture.

Instead of processing uploaded files directly, the backend will upload the file to Amazon S3. An **S3 ObjectCreated** event will automatically invoke an AWS Lambda function, which will validate the uploaded CSV file and insert the records into Amazon RDS.

```text
User
   │
   ▼
Frontend
   │
   ▼
Backend (Amazon ECS)
   │
Upload CSV
   ▼
Amazon S3
   │
ObjectCreated Event
   ▼
AWS Lambda
   │
Validate & Process File
   ▼
Amazon RDS
```

This design separates file upload from file processing, resulting in a more modular, scalable, and production-ready architecture.

---

# Why Introduce Amazon S3?

The purpose of introducing Amazon S3 is **not to reduce the database workload**, since the same data is ultimately stored in Amazon RDS.

Instead, S3 acts as a durable landing zone for uploaded files and provides several architectural benefits:

* Decouples file upload from data processing.
* Allows asynchronous processing using AWS Lambda.
* Preserves the original uploaded file for auditing and troubleshooting.
* Enables failed files to be reprocessed without requiring another upload.
* Simplifies future integrations with additional AWS services such as Amazon SQS, AWS Glue, or analytics pipelines.

---

# Project Objectives

The primary objectives of this project are:

* Redesign the existing upload workflow using an event-driven architecture.
* Allow only CSV files to be uploaded through the application.
* Automatically process uploaded files using AWS Lambda.
* Store transaction or quiz data in Amazon RDS after validation.
* Reuse the existing Terraform modules and GitHub Actions CI/CD pipeline.
* Follow AWS best practices for networking, security, automation, and scalability.

---

# Scope

The sope of this project focuses on:

* Understanding the existing upload workflow.
* Modifying the application to accept only CSV uploads.
* Updating the backend to upload files to Amazon S3.
* Preparing the infrastructure for AWS Lambda integration.
* Reusing the existing Infrastructure as Code (Terraform) and CI/CD pipeline.

Additional enhancements will be documented as each implementation phase is completed.

---

# Technology Stack

* Python
* Terraform
* GitHub Actions
* Docker
* Amazon ECS (Fargate)
* Amazon ECR
* Amazon S3
* AWS Lambda
* Amazon RDS (PostgreSQL)
* AWS IAM
* Amazon VPC
* Security Groups
* CloudWatch

---



