# DevOps Dojo - Terraform AWS Infrastructure

## Project Overview

DevOps Dojo is a hands-on DevOps project focused on building and deploying a production-style AWS infrastructure for a three-tier application using Infrastructure as Code (IaC) principles.

The target architecture consists of:

* Frontend Tier
* Backend Tier
* Database Tier

The infrastructure is being built using Terraform with a strong focus on:

* Reusability
* Modularity
* Dynamic resource creation
* Multi-environment support
* Terraform best practices
* Scalable infrastructure design

This project is being developed incrementally, with each infrastructure component being implemented, validated, and documented before moving to the next phase.

---

# Goal

The goal of this project is to build a fully automated, reusable, and scalable AWS infrastructure using Terraform while applying real-world DevOps and Cloud Engineering practices.

---

# High Level Architecture

```text
Internet
    │
    ▼
Route53
    │
    ▼
ACM Certificate
    │
    ▼
Application Load Balancer
    │
    ▼
Target Group
    │
    ▼
Frontend ECS Service
    │
    ▼
Service Connect
    │
    ▼
Backend ECS Service
    │
    ▼
CloudWatch Logs
```

---

# Recommended Testing Cycle

Before deploying any infrastructure changes:

## Format

```bash
terraform fmt -recursive
```

## Validate

```bash
terraform validate
```

## Initialize

```bash
terraform init -backend-config=vars/dev.tfbackend -reconfigure
```

## Plan

```bash
terraform plan -var-file=vars/dev.tfvars
```

## Apply

```bash
terraform apply -var-file=vars/dev.tfvars
```

## Destroy

```bash
terraform destroy -var-file=vars/dev.tfvars
```
---

## Phase 1 - Network Module

Completed successfully.

A reusable Terraform Network Module has been created and invoked from the project configuration.

The module dynamically provisions:

* VPC
* Public Subnets
* Private Subnets
* RDS Subnets
* Internet Gateway
* Public Route Table
* Private Route Tables
* Route Table Associations
* Elastic IPs
* NAT Gateway(s)
* NAT Gateway Routes

---

# Network Module Features

### Dynamic Subnet Creation

Public, Private, and RDS subnets are created dynamically using Terraform count expressions and environment-specific variables.

### Dynamic NAT Gateway Deployment

The module supports multiple deployment models:

#### Single NAT Gateway

Used for cost-optimized environments such as Development.

```hcl
need_ngw        = true
need_single_ngw = true
```

#### Multiple NAT Gateways

Used for highly available Production environments.

```hcl
need_ngw        = true
need_single_ngw = false
```

#### No NAT Gateway

Used for isolated environments where outbound internet access is not required.

```hcl
need_ngw = false
```

### Multi-Environment Ready

The same module can be reused across multiple environments by changing only the tfvars configuration.

Examples:

* dev
* stage
* prod

### Dynamic Route Table Association

The module automatically associates subnets with the correct route tables based on the NAT Gateway configuration.

### Resource Tagging Strategy

All resources follow a standardized naming convention and tagging structure.

Example:

```text
dev-DevopsDojo-public-1
dev-DevopsDojo-private-1
dev-DevopsDojo-rds-1
```

Tags include:

```text
managed_by
project
environment
module_name
Name
```

---

# 2. Route53

Route53 is used to provide a friendly DNS name for the application.

Example:

```text
app.devopsdojo.com
```

Instead of:

```text
alb-123456.us-east-1.elb.amazonaws.com
```

---

# 3. ACM Certificate

AWS Certificate Manager (ACM) is used to provide SSL/TLS certificates.

Purpose:

- HTTPS Communication
- Secure Browser Connections
- Certificate Management by AWS

Flow:

```text
User
  │
  ▼
HTTPS Request
  │
  ▼
ACM Certificate
  │
  ▼
ALB
```

---

# 4. Application Load Balancer (ALB)

The ALB acts as the entry point for external traffic.

### Responsibilities

- Receives user traffic
- Terminates SSL
- Routes requests to ECS tasks
- Performs health checks

---

## Listener Flow

### HTTP Listener

```text
Port 80
```

Receives incoming HTTP requests.

### HTTPS Listener

```text
Port 443
```

Receives encrypted HTTPS traffic using ACM certificates.

---

## Target Group

The Target Group maintains healthy ECS tasks.

Example:

```text
Frontend Task

IP = 10.0.3.15
Port = 80
```

Registered Target:

```text
10.0.3.15:80
```

---

# 5. ECS Service Discovery

A Service Discovery Namespace is created.

Example:

```text
dojo-dev-namespace
```

This namespace is attached to the ECS Cluster.

Purpose:

- Service Discovery
- Service Connect Communication
- Internal DNS Resolution

---

# 6. ECS Cluster

The ECS Cluster is the logical container for running ECS Services.

Example:

```text
dojo-dev-cluster
```

The cluster is configured with Service Connect defaults.

---

# 7. ECS Task Definitions

Task Definitions act as blueprints for containers.

Each Task Definition defines:

- Container Image
- CPU
- Memory
- Port Mapping
- Environment Variables
- Logging Configuration

Example:

```text
Frontend
Port : 80

Backend
Port : 8000
```

---

# 8. IAM Roles

IAM Roles are used to allow ECS to interact with AWS services.

### ECS Execution Role

Responsibilities:

- Pull Docker Images from ECR
- Send Logs to CloudWatch
- Read Secrets Manager
- Read Parameter Store

Example:

```text
ECR
 ↓
ECS Task
```

---

# 9. CloudWatch Logs

Each ECS service sends logs to CloudWatch.

Purpose:

- Application Logs
- Startup Logs
- Error Logs
- Debugging

Example:

```text
Frontend Logs
Backend Logs
```

---

# 10. ECS Services

ECS Services are responsible for running and maintaining ECS Tasks.

Current Services:

```text
Frontend Service
Backend Service
```

Terraform dynamically creates services using:

```hcl
for_each = local.ecs_services_map
```

Benefits:

- Single Source of Truth
- Easier Maintenance
- Easier Scaling
- New Services Can Be Added Quickly

---

# Frontend Service Flow

Frontend is internet-facing.

Traffic Flow:

```text
User
  │
  ▼
ALB
  │
  ▼
Target Group
  │
  ▼
Frontend ECS Task
```

The frontend service is automatically registered into the Target Group through the ECS Service Load Balancer configuration.

---

# Backend Service Flow

Backend is private.

No ALB is attached.

Flow:

```text
Frontend
   │
   ▼
backend:8000
   │
   ▼
Backend ECS Task
```

Communication happens through Service Connect.

---

# Service Connect Flow

Service Connect provides service-to-service communication using DNS names.

Example:

```text
Frontend
    │
    ▼
backend:8000
    │
    ▼
Backend
```

Benefits:

- No hardcoded IPs
- Automatic Service Discovery
- Easier Scaling
- Internal Communication

---

# ECS Networking

Each ECS Task runs inside:

```text
Private Subnets
```

Network Configuration controls:

- Subnets
- Security Groups
- Public IP Assignment

Example:

```text
Frontend Task
    │
    ▼
Frontend Security Group

Backend Task
    │
    ▼
Backend Security Group
```

---

# Dynamic Load Balancer Registration

Frontend Service:

```text
need_alb = true
```

Result:

```text
Frontend Task
    │
    ▼
Registered Into Target Group
```

Backend Service:

```text
need_alb = false
```

Result:

```text
No Target Group Registration
```

---

# 11. Database Layer (RDS & Aurora)

The Database Layer is responsible for storing and retrieving application data.

The project supports different database architectures based on the environment:

```text
Development Environment
        │
        ▼
Amazon RDS PostgreSQL Instance

Production Environment
        │
        ▼
Amazon Aurora PostgreSQL Cluster
```

This approach balances:

* Cost Optimization
* Simplicity
* High Availability
* Scalability

---

# Database Architecture

## Development Environment

Development environments use a standard PostgreSQL RDS Instance.

Flow:

```text
Backend ECS Service
        │
        ▼
RDS Endpoint
        │
        ▼
PostgreSQL Database
```

Example:

```text
dojo-dev-rds-instance
```

Benefits:

* Lower Cost
* Easy Management
* Faster Provisioning
* Suitable for Development and Testing

---

## Production Environment

Production environments use Aurora PostgreSQL.

Flow:

```text
Backend ECS Service
        │
        ▼
Aurora Cluster Endpoint
        │
        ▼
Writer Instance
        │
 ┌──────┴──────┐
 ▼             ▼
Reader      Reader
```

Benefits:

* High Availability
* Automatic Failover
* Read Scaling
* Better Performance
* Multi-AZ Architecture

---

# Database Subnet Group

A dedicated Database Subnet Group is created using private RDS subnets.

Purpose:

* Isolate databases from public access
* Improve security
* Restrict database traffic to internal services

Flow:

```text
RDS Subnet Group
        │
        ▼
RDS Private Subnets
```

Only backend services can access the database.

---

# Database Security

The database is deployed inside private subnets and is not publicly accessible.

```text
publicly_accessible = false
```

Access is controlled through Security Groups.

Flow:

```text
Backend ECS Task
        │
        ▼
Backend Security Group
        │
        ▼
RDS Security Group
        │
        ▼
Database
```

This ensures that only backend services can communicate with the database.

---

# Dynamic Database Configuration

Database configurations are externalized using Terraform variables and environment-specific tfvars files.

Examples:

```text
dev.tfvars
prod.tfvars
```

This allows:

* Environment Specific Configuration
* Reusability
* Easier Maintenance
* Reduced Hardcoding

Example:

```text
RDS Instance Config
Aurora Cluster Config
Database Name
```

Terraform reads the configuration from tfvars and dynamically provisions the appropriate database resources.

---

# Database Credentials Management

Database credentials are not hardcoded.

Terraform generates secure passwords using:

```text
random_password
```

The generated credentials are stored securely in:

```text
AWS Secrets Manager
```

Benefits:

* Secure Credential Storage
* No Hardcoded Passwords
* Easier Secret Rotation
* Centralized Secret Management

---

# Database Connection String

A database connection string is dynamically generated using Terraform locals.

Example:

```text
postgresql://username:password@host:5432/database
```

The connection string automatically changes based on the environment.

Development:

```text
RDS Address
```

Production:

```text
Aurora Cluster Endpoint
```

This ensures the backend application always connects to the correct database endpoint.

---

# Backend to Database Communication

The backend application communicates with the database using the DATABASE_URL environment variable.

Flow:

```text
Terraform
      │
      ▼
Connection String
      │
      ▼
Secrets Manager
      │
      ▼
ECS Task Environment Variable
      │
      ▼
Flask Application
      │
      ▼
RDS / Aurora
```

The Flask application reads:

```text
DATABASE_URL
```

and uses it to establish database connectivity.

---

# Single Source of Truth

Database names are maintained through Terraform variables.

Example:

```text
database_name
```

The same value is reused across:

* RDS Instance
* Aurora Cluster
* Backend Application

Benefits:

* Consistency
* Easier Maintenance
* Reduced Configuration Drift

---

# Database Layer Summary

The database layer follows a production-oriented design:

* RDS PostgreSQL for Development
* Aurora PostgreSQL for Production
* Private Subnet Deployment
* Security Group Based Access Control
* Secrets Manager for Credential Storage
* Dynamic Connection String Generation
* Environment Specific Configuration
* Single Source of Truth Design

This architecture provides a balance between simplicity in development and scalability in production workloads.

---

# 12. Amazon Elastic Container Registry (ECR)

ECR repositories are created dynamically using the same service configuration used by ECS.

Terraform:

```hcl
resource "aws_ecr_repository" "ecr_repositories" {
  for_each = local.ecs_services_map

  name = "${var.project}-${var.environment}-${each.key}"
}
```

Current repositories created:

```text
DevopsDojo-dev-backend
DevopsDojo-dev-frontend
```

The repositories are created dynamically using:

```hcl
for_each = local.ecs_services_map
```

which means whenever a new service is added to the service configuration, a new ECR repository will automatically be created.

Example:

```text
backend
frontend
auth
```

will automatically create:

```text
DevopsDojo-dev-backend
DevopsDojo-dev-frontend
DevopsDojo-dev-auth
```

Repository URLs are later used by ECS Task Definitions to pull Docker images.

Flow:

```text
Docker Build
    │
    ▼
Docker Push
    │
    ▼
Amazon ECR
    │
    ▼
ECS Task Definition
    │
    ▼
ECS Service
```

To avoid accidental deletion of repositories during:

```bash
terraform destroy
```

the following lifecycle rule can be used:

```hcl
lifecycle {
  prevent_destroy = true
}
```

---





