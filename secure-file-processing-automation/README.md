# Enterprise Malware Scanning Pipeline using AWS, Python & ClamAV

## Overview

This project demonstrates how to build an enterprise-grade malware scanning solution using AWS services, Python, Docker, and ClamAV. The primary objective is to automatically scan every file uploaded to Amazon S3 before it is consumed by downstream applications.

In many organizations, users upload documents, images, ZIP files, PDFs, spreadsheets, and other files to cloud storage. These files may unintentionally or maliciously contain viruses or malware. Scanning each file manually is not practical, especially when thousands of files are uploaded every day.

This project automates the entire scanning process by building an event-driven architecture that securely processes uploaded files without any manual intervention.

---

## Project Objective

The main objective of this project is to build a secure, scalable, and automated malware scanning pipeline that:

- Detects every file uploaded to Amazon S3.
- Automatically scans the uploaded file using ClamAV.
- Tags the file with its scan result.
- Copies clean files to a trusted location.
- Sends notifications whenever malware is detected.
- Demonstrates how Python can automate AWS services in a real-world enterprise solution.

Rather than simply deploying AWS resources, this project focuses on building an automation workflow where Python acts as the orchestration engine connecting multiple cloud services together.

---

## What This Project Does

Whenever a file is uploaded to the inbound S3 bucket, Amazon S3 generates an event notification. Instead of directly invoking the scanner, the event is sent to Amazon SQS, allowing the system to process uploads asynchronously and reliably.

A Python application running inside a Docker container on Amazon ECS continuously polls the SQS queue for new upload events. When a message is received, the application downloads the uploaded file from Amazon S3 and scans it using the ClamAV antivirus engine.

After the scan is completed, the application updates the S3 object by adding tags that indicate whether the file has been scanned and whether the result is **CLEAN** or **DIRTY**.

If the file is clean, it is copied to the designated clean bucket for further processing by downstream applications. If malware is detected, the application sends an Amazon SNS notification so that administrators can take immediate action.

Finally, the processed message is removed from the SQS queue to prevent duplicate processing.

The entire workflow runs automatically without requiring any manual effort.

---

## Technologies Used

This project combines several technologies to build a complete cloud-native security automation solution.

### Cloud Services

- Amazon S3
- Amazon SQS
- Amazon ECS
- Amazon ECR
- Amazon SNS
- Amazon CloudWatch
- AWS IAM
- Amazon VPC

### Infrastructure

- Terraform

### Programming

- Python
- Boto3 (AWS SDK for Python)

### Containerization

- Docker

### Security

- ClamAV Antivirus

### Version Control

- Git
- GitHub

---

## Why This Project?

This project demonstrates how Python can be used to automate AWS operations, process cloud events, execute Linux commands, and build intelligent workflows instead of only managing infrastructure.

By combining Python with AWS services, this project represents a real-world enterprise use case where cloud infrastructure, automation, and security work together.

---

## Key Features

- Fully automated malware scanning
- Event-driven architecture
- Containerized Python application
- ClamAV antivirus integration
- S3 object tagging
- Automatic notification for infected files
- Infrastructure as Code using Terraform
- Scalable deployment using Amazon ECS
- Decoupled architecture using Amazon SQS
- Cloud-native design following AWS best practices

---

## High-Level Workflow

1. A user uploads a file to the inbound Amazon S3 bucket.
2. Amazon S3 generates an event notification.
3. The event is delivered to Amazon SQS.
4. The Python scanner running on Amazon ECS receives the SQS message.
5. The uploaded file is downloaded from Amazon S3.
6. ClamAV scans the file for malware.
7. The S3 object is tagged with the scan result.
8. Clean files are copied to the clean bucket.
9. Infected files trigger an Amazon SNS notification.
10. The SQS message is deleted after successful processing.

---

## Learning Outcomes

- Building event-driven cloud architectures
- Python automation using Boto3
- Docker containerization
- Amazon ECS
- Amazon S3
- Amazon SQS
- Amazon SNS
- Terraform
- Infrastructure as Code
- Linux process automation
- Security automation using ClamAV
- Designing scalable cloud-native applications

---

## Final Goal

The goal of this project is not only to build an automated malware scanning system but also to understand how multiple AWS services can be integrated using Python to solve a real-world business problem.

By the end of this project, I will have built a production-style security automation pipeline that demonstrates cloud architecture, infrastructure automation, containerization, and Python development working together as a complete solution.