# Event-Driven File Processing System using AWS

## Project Overview

This project is an enhancement of my existing **DevOps Dojo** application, which was previously deployed on AWS using **Terraform**, **GitHub Actions**, **Docker**, **Amazon ECS Fargate**, and **Amazon RDS**.

Instead of modifying the existing project, a separate copy has been created to implement a **production-style event-driven architecture** while preserving the original application.

## Project Objective

The objective of this project is to redesign the existing file upload workflow by introducing a **serverless event-driven pipeline** using **Amazon S3** and **AWS Lambda**.

Instead of writing uploaded files directly to the database, the application will upload CSV files to an S3 bucket. An S3 ObjectCreated event will automatically trigger a Lambda function, which will validate the uploaded file and insert the data into Amazon RDS.

## Existing Architecture

```text
User
   │
   ▼
Frontend
   │
   ▼
Backend (ECS)
   │
   ▼
Amazon RDS
```

## Target Architecture

```text
User
   │
   ▼
Frontend
   │
   ▼
Backend (ECS)
   │
Upload CSV
   ▼
Amazon S3
   │
ObjectCreated Event
   ▼
AWS Lambda
   │
Validate & Process CSV
   ▼
Amazon RDS
```

## Key Enhancements

* Implement an event-driven architecture using Amazon S3 and AWS Lambda.
* Restrict uploads to CSV files only.
* Automatically trigger Lambda when a new file is uploaded.
* Validate uploaded data before inserting it into the database.
* Store successfully processed files in an **archive** location.
* Move failed files to an **error** location for troubleshooting and reprocessing.
* Secure database connectivity using VPC, Security Groups, IAM Roles, and AWS Secrets Manager.
* Provision all AWS infrastructure using Terraform.
* Deploy infrastructure and application changes through GitHub Actions CI/CD.
* Implement logging and monitoring using Amazon CloudWatch.

## Technologies Used

* Python
* Terraform
* GitHub Actions
* Docker
* Amazon ECS (Fargate)
* Amazon ECR
* Amazon S3
* AWS Lambda
* Amazon RDS (PostgreSQL)
* IAM
* VPC
* Security Groups
* VPC Endpoints
* AWS Secrets Manager
* Amazon CloudWatch

## Project Goal

The primary goal of this project is to gain hands-on experience in designing and implementing a real-world, cloud-native event-driven architecture while following AWS best practices for scalability, reliability, security, and automation. This project demonstrates Infrastructure as Code (IaC), CI/CD, serverless computing, and modern cloud design patterns commonly used in production environments.
