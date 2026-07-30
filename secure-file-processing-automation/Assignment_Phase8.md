# Assignment - Phase 8
# Deploy File Scanner to Amazon ECS (Fargate)

## Objective

Deploy the Dockerized File Scanner application to Amazon ECS using AWS Fargate. The application should continuously poll Amazon SQS, scan files using ClamAV, move files to the appropriate S3 bucket, publish SNS notifications, and run completely inside AWS without using local AWS credentials.

---

# Architecture

```text
                    +----------------------+
                    |      Amazon S3       |
                    |   Landing Bucket     |
                    +----------+-----------+
                               |
                               | S3 Event Notification
                               |
                               v
                    +----------------------+
                    |      Amazon SQS      |
                    +----------+-----------+
                               |
                               |
                               v
                 +----------------------------+
                 | Amazon ECS Service         |
                 | Desired Tasks = 1          |
                 +-------------+--------------+
                               |
                               v
                    +----------------------+
                    | ECS Fargate Task     |
                    |----------------------|
                    | Download File        |
                    | ClamAV Scan          |
                    | Tag Object           |
                    | Move Object          |
                    | Publish SNS          |
                    | Delete SQS Message   |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | Amazon CloudWatch    |
                    | Logs                 |
                    +----------------------+
```

---

# Phase 8 Overview

During this phase we deployed the malware scanning application to Amazon ECS using AWS Fargate.

Completed Tasks:

- Created Amazon ECR Repository
- Pushed Docker Image to ECR
- Created IAM Roles
- Created ECS Cluster
- Created ECS Task Definition
- Created Production Style Networking
- Created ECS Service
- Successfully executed the application inside Fargate
- Verified complete malware scanning flow

---

# Step 1 - Create Amazon ECR Repository

Navigation

```
AWS Console
→ Amazon ECR
→ Repositories
→ Create Repository
```

Repository Name

```
file-scanner
```

Repository Type

```
Private
```

---

# Step 2 - Login to Amazon ECR

```bash
aws ecr get-login-password \
--region us-east-1 \
| docker login \
--username AWS \
--password-stdin \
<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

Example

```bash
aws ecr get-login-password \
--region us-east-1 \
| docker login \
--username AWS \
--password-stdin \
023192525105.dkr.ecr.us-east-1.amazonaws.com
```

---

# Step 3 - Build Docker Image

Initially the image was built using

```bash
docker build -t file-scanner:1.0 .
```

Since development was done on Apple Silicon, ECS failed with

```
CannotPullContainerError

image manifest does not contain descriptor matching platform linux/amd64
```

Solution

Rebuild the image explicitly for AMD64.

```bash
docker buildx build \
--platform linux/amd64 \
-t file-scanner:1.0 \
--load .
```

---

# Step 4 - Tag Docker Image

```bash
docker tag \
file-scanner:1.0 \
023192525105.dkr.ecr.us-east-1.amazonaws.com/file-scanner:1.0
```

---

# Step 5 - Push Image to ECR

```bash
docker push \
023192525105.dkr.ecr.us-east-1.amazonaws.com/file-scanner:1.0
```

---

# Step 6 - Create IAM Roles

## ECS Task Execution Role

Navigation

```
IAM
→ Roles
→ Create Role
```

Trusted Entity

```
Elastic Container Service Task
```

Attached Policy

```
AmazonECSTaskExecutionRolePolicy
```

Purpose

Used by ECS to

- Pull Docker Images
- Send Logs to CloudWatch
- Retrieve Secrets (future)

---

## ECS Task Role

Navigation

```
IAM
→ Roles
→ Create Role
```

Trusted Entity

```
Elastic Container Service Task
```

Policies Attached

```
AmazonS3FullAccess
AmazonSQSFullAccess
AmazonSNSFullAccess
```

Purpose

Used by the application running inside the container.

The Python application uses this role to access

- Amazon S3
- Amazon SQS
- Amazon SNS

> Note:
> These AWS managed policies were used during development.
> They will later be replaced with a custom least-privilege IAM policy.

---

# Step 7 - Create ECS Cluster

Navigation

```
Amazon ECS
→ Clusters
→ Create Cluster
```

Configuration

```
Cluster Name

file-scanner-cluster
```

Infrastructure

```
AWS Fargate
```

---

# Step 8 - Create Task Definition

Navigation

```
Amazon ECS
→ Task Definitions
→ Create
```

Configuration

```
Family

file-scanner
```

Launch Type

```
Fargate
```

Operating System

```
Linux
```

CPU Architecture

```
X86_64
```

Task Size

```
0.5 vCPU

1 GB Memory
```

Task Role

```
file-scanner-task-role
```

Execution Role

```
ecsTaskExecutionRole
```

---

## Container Configuration

Image

```
023192525105.dkr.ecr.us-east-1.amazonaws.com/file-scanner:1.0
```

Environment Variables

```
AWS_REGION
QUEUE_URL
CLEAN_BUCKET
QUARANTINE_BUCKET
TOPIC_ARN
```

CloudWatch Logs

```
Log Group

/ecs/file-scanner

Stream Prefix

ecs
```

---

# Step 9 - Create Production VPC

Navigation

```
VPC
→ Create VPC
→ VPC and More
```

Configuration

```
CIDR

10.0.0.0/16
```

Availability Zones

```
2
```

Public Subnets

```
2
```

Private Subnets

```
2
```

NAT Gateway

```
1
```

DNS Hostnames

```
Enabled
```

DNS Resolution

```
Enabled
```

AWS automatically created

- VPC
- Internet Gateway
- NAT Gateway
- Elastic IP
- Public Route Table
- Private Route Table
- Public Subnets
- Private Subnets

---

# Networking Architecture

```text
Internet
    |
Internet Gateway
    |
-------------------------
Public Subnets
    |
NAT Gateway
    |
-------------------------
Private Subnets
    |
ECS Fargate Tasks
```

The ECS Tasks run inside Private Subnets.

Outbound internet connectivity is provided through the NAT Gateway.

---

# Step 10 - Create Security Group

Navigation

```
VPC
→ Security Groups
→ Create
```

Configuration

```
Name

file-scanner-sg
```

Inbound Rules

```
None
```

Outbound Rules

```
All Traffic
```

Since the application is a background worker, no inbound traffic is required.

---

# Step 11 - Create ECS Service

Navigation

```
Amazon ECS
→ Cluster
→ Services
→ Create
```

Configuration

```
Launch Type

Fargate
```

Task Definition

```
file-scanner
```

Service Name

```
file-scanner-service
```

Desired Tasks

```
1
```

VPC

```
project-vpc
```

Subnets

```
Private Subnets
```

Public IP

```
Disabled
```

Security Group

```
file-scanner-sg
```

Load Balancer

```
None
```

Auto Scaling

```
Disabled
```

---

# Architecture Issue Encountered

The ECS task initially failed with

```
CannotPullContainerError

image manifest does not contain descriptor matching platform linux/amd64
```

Root Cause

Docker image was built on Apple Silicon without specifying the platform.

Solution

Rebuild the image using

```bash
docker buildx build \
--platform linux/amd64 \
-t file-scanner:1.0 \
--load .
```

Push the image again to ECR and force a new ECS deployment.

---

# Verification

Successfully verified

- ECS Task Started
- Image Pulled from ECR
- ClamAV Started
- Connected to Amazon SQS
- Downloaded Object from Amazon S3
- Malware Scan Completed
- Tagged S3 Object
- Moved Object to Clean Bucket
- Published Amazon SNS Notification
- Deleted SQS Message
- Polling resumed successfully

CloudWatch Logs confirmed the entire workflow executed successfully.

---

# Important Learning Points

## ECS Task Execution Role

Used by ECS infrastructure.

Responsibilities

- Pull images from ECR
- Push logs to CloudWatch

---

## ECS Task Role

Used by the application running inside the container.

The boto3 SDK automatically retrieves temporary credentials from this role.

No AWS access keys or AWS_PROFILE are required inside ECS.

---

## Why Private Subnets?

The application should not be directly accessible from the internet.

Only outbound communication is required.

Internet access is provided using the NAT Gateway.

---

## Why No Load Balancer?

The application is not a web service.

It continuously polls Amazon SQS and processes background jobs.

Therefore, no HTTP endpoint or Application Load Balancer is required.

---

# Phase 8 Outcome

Successfully deployed the File Scanner application to Amazon ECS using AWS Fargate.

The complete malware scanning workflow now runs entirely inside AWS.

Verified Features

- Docker Image deployed successfully
- ECS Service running
- Fargate Task running
- ClamAV working
- Amazon SQS integration
- Amazon S3 integration
- Amazon SNS integration
- CloudWatch Logs integration
- Private networking using VPC and NAT Gateway

---

# Next Phase

Phase 9

Implement automatic scaling of ECS Tasks based on Amazon SQS queue depth.

Goal

```
Queue receives message

↓

Automatically start ECS Task

↓

Process files

↓

Queue becomes empty

↓

Automatically scale ECS Tasks back to zero
```