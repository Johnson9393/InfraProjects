# Assignment Phase 2

## Objective

In this phase, we prepare the compute infrastructure required to run our malware scanning application.

The application will eventually run inside an Amazon ECS container. Before that can happen, we need to create the following AWS resources:

- Amazon ECS Cluster
- IAM Task Role
- Amazon ECR Repository

At the end of this phase, the infrastructure is ready to host our Dockerized Python application.

---

# Current Architecture

```text
                Upload File
                     │
                     ▼
      +-----------------------------+
      | Amazon S3 Landing Bucket    |
      +-----------------------------+
                     │
                     ▼
      +-----------------------------+
      | Amazon SQS                  |
      +-----------------------------+
                     │
                     ▼
      +-----------------------------+
      | Amazon ECS Cluster          |
      +-----------------------------+
                     ▲
                     │
      +-----------------------------+
      | Amazon ECR Repository       |
      +-----------------------------+
```

---

# Step 1 - Create Amazon ECS Cluster

## What is Amazon ECS?

Amazon Elastic Container Service (ECS) is a fully managed container orchestration service.

It is responsible for running Docker containers without requiring us to manually manage the underlying infrastructure.

Our malware scanning application will eventually run as a Docker container inside ECS.

---

## Navigation

```text
AWS Console
    ↓
Amazon ECS
    ↓
Clusters
    ↓
Create Cluster
```

---

## Configuration

| Setting | Value |
|----------|-------|
| Cluster Name | file-scan-cluster-dev |
| Infrastructure | AWS Fargate |

Leave the remaining settings as default.

Click **Create Cluster**.

---

## Why AWS Fargate?

AWS Fargate is a serverless compute engine for containers.

Instead of creating and maintaining EC2 instances, AWS automatically provisions the required compute resources.

This allows us to focus only on our application.

---

# Step 2 - Create IAM Task Role

## Why do we need an IAM Task Role?

Our Python application will interact with multiple AWS services.

For example, it will:

- Read messages from Amazon SQS
- Download files from Amazon S3
- Write logs to Amazon CloudWatch

Instead of storing AWS Access Keys inside the application, ECS securely provides temporary credentials through an IAM Role.

This is the recommended AWS best practice.

---

## Navigation

```text
AWS Console
    ↓
IAM
    ↓
Roles
    ↓
Create Role
```

---

## Trusted Entity

| Setting | Value |
|----------|-------|
| Trusted Entity | AWS Service |
| Service | Elastic Container Service |
| Use Case | Elastic Container Service Task |

Click **Next**.

---

## Attach Policies

Attach the following AWS Managed Policies:

- AmazonS3FullAccess
- AmazonSQSFullAccess
- CloudWatchLogsFullAccess

---

## Permissions Boundary

For this project, no Permissions Boundary is required.

Ensure:

```text
Permissions Boundary

Not Set
```

---

## Role Name

```text
file-scan-task-role-dev
```

Click **Create Role**.

---

## Understanding Permissions Boundary

A Permissions Boundary defines the maximum permissions that an IAM Role can use.

It does **not** grant permissions.

AWS allows an action only when:

- The attached IAM Policy allows it.
- The Permissions Boundary also allows it (if one is configured).

Since this is a learning project, no Permissions Boundary is required.

---

# Step 3 - Create Amazon ECR Repository

## What is Amazon ECR?

Amazon Elastic Container Registry (ECR) is AWS's managed Docker image registry.

Instead of running Docker images directly from our local machine, ECS pulls Docker images from ECR.

Our Python malware scanner will later be built as a Docker image and pushed into this repository.

---

## Navigation

```text
AWS Console
    ↓
Amazon ECR
    ↓
Create Repository
```

---

## Configuration

| Setting | Value |
|----------|-------|
| Repository Type | Private |
| Repository Name | file-scan-scanner-dev |

Leave the remaining settings as default.

Click **Create Repository**.

---

## Why do we need ECR?

The overall deployment flow will be:

```text
Python Source Code
        │
        ▼
Docker Build
        │
        ▼
Docker Image
        │
        ▼
Amazon ECR
        │
        ▼
Amazon ECS
        │
        ▼
Running Container
```

Amazon ECS always pulls the Docker image from Amazon ECR before starting a container.

---

# Current Infrastructure After Phase 2

```text
                Upload File
                     │
                     ▼
      +-----------------------------+
      | Amazon S3 Landing Bucket    |
      +-----------------------------+
                     │
                     ▼
      +-----------------------------+
      | Amazon SQS                  |
      +-----------------------------+
                     │
                     ▼
      +-----------------------------+
      | Amazon ECS Cluster          |
      +-----------------------------+
                     │
                     ▼
      +-----------------------------+
      | ECS Task (To be created)    |
      +-----------------------------+
                     ▲
                     │
      +-----------------------------+
      | Amazon ECR Repository       |
      +-----------------------------+
```