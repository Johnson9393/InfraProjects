# Reflections - DevOps Dojo

## Overview

This document captures my learnings, observations, design decisions, and key takeaways while building the DevOps Dojo infrastructure project using Terraform and AWS.

The goal is not only to provision infrastructure but also to understand why certain architectural decisions were made and how Terraform behaves in real-world scenarios.

---

# Testing Process

For every infrastructure change I follow:

```bash
terraform fmt -recursive
```

```bash
terraform validate
```

```bash
terraform init \
  -backend-config=vars/dev.tfbackend \
  -reconfigure
```

```bash
terraform plan \
  -var-file=vars/dev.tfvars
```

```bash
terraform apply \
  -var-file=vars/dev.tfvars
```

Verify resources in AWS Console.

Finally:

```bash
terraform destroy \
  -var-file=vars/dev.tfvars
```

This helps validate infrastructure while avoiding unnecessary AWS charges.

---

# Phase 1 - Network Module

## Objective

Build a reusable and dynamic Terraform Network Module that can support multiple environments and different deployment patterns without duplicating code.

---

# Key Learnings

## 1. Modules Improve Reusability

Instead of creating VPC, Subnets, NAT Gateways, and Route Tables directly in the project, I created a reusable Network Module.

Benefits:

* Reduced code duplication
* Easier maintenance
* Reusable across multiple projects
* Consistent infrastructure patterns

Module structure:

```text
modules/
└── network/
    ├── vpc.tf
    ├── variables.tf
    └── outputs.tf
```

---

## 2. Dynamic Infrastructure Creation

I used Terraform count expressions to dynamically create resources.

Examples:

* Public Subnets
* Private Subnets
* RDS Subnets
* NAT Gateways
* Route Tables
* Route Table Associations

This allows the same code to work for different environments without modification.

---

## 3. NAT Gateway Design

The module supports three deployment models.

### Single NAT Gateway

Used for Development environments to reduce cost.

```hcl
need_ngw        = true
need_single_ngw = true
```

Result:

* One NAT Gateway
* One Elastic IP
* One Private Route Table

---

### Multiple NAT Gateways

Used for Production environments to improve availability.

```hcl
need_ngw        = true
need_single_ngw = false
```

Result:

* One NAT Gateway per Public Subnet
* One Elastic IP per NAT Gateway
* One Private Route Table per NAT Gateway

---

### No NAT Gateway

Used when outbound internet access is not required.

```hcl
need_ngw = false
```

Result:

* No NAT Gateway
* No Elastic IP
* No NAT Route

Private Route Tables are still created because private subnets require route table associations.

---

# Validation Logic

I learned that validation should live inside the module rather than in every environment.

Example:

```hcl
validation {
  condition = (
    var.need_single_ngw ||
    length(var.private_subnets) == length(var.public_subnets)
  )

  error_message = "When using multiple NAT Gateways, public and private subnet counts must be equal."
}
```

Benefits:

* Validation is written once
* Every consumer of the module automatically gets the same validation

---

# Resource Naming Strategy

I standardized naming using:

```text
environment-project-resource
```

Examples:

```text
dev-DevopsDojo-vpc
dev-DevopsDojo-public-1
dev-DevopsDojo-private-1
dev-DevopsDojo-rds-1
```

Benefits:

* Easy identification in AWS Console
* Environment visibility
* Consistent naming convention

---

# Tagging Strategy

I learned the difference between Module Tags and Provider Default Tags.

## Provider Default Tags

Used globally.

```hcl
managed_by = "terraform"
project    = var.project
environment = var.environment
```

Applied automatically to all resources.

---

## Module Tags

Used for module-specific information.

```hcl
module_name = "network"
```

Applied through merge().

Example:

```hcl
tags = merge(
  var.default_tags,
  {
    Name = var.vpc_name
  }
)
```

Benefits:

* Global consistency
* Module ownership visibility
* Easier troubleshooting

---

# State Management Learnings

## S3 Backend

Terraform state is stored remotely in S3.

Benefits:

* Shared state
* Centralized management
* Team collaboration

---

## Local Files vs State Locking

I learned that:

```text
.terraform/
```

and

```text
.terraform.lock.hcl
```

are not state locks.

They are used for:

* Provider downloads
* Backend metadata
* Module cache
* Provider version locking

---

## State Locking

State locking is a separate concept.

Modern Terraform supports:

```hcl
use_lockfile = true
```

inside the S3 backend.

This creates a lock directly in S3.

Benefits:

* Prevents concurrent terraform apply operations
* No DynamoDB table required
* Simpler backend management

---

# Environment Design Learnings

I chose to follow a single source of truth approach.

Goals:

* One codebase
* One set of Terraform files
* Environment-specific behavior through tfvars
* Reduced duplication

Environment differences are controlled through:

* Variables
* Conditionals
* Count expressions
* Module inputs

Examples:

* Single NAT Gateway in Dev
* Multiple NAT Gateways in Prod
* Different instance sizes
* Different deployment patterns

without duplicating Terraform code.

---

# ECS, ALB and Service Connect

## Overview

While building the ECS infrastructure for the DevOps Dojo project, I focused on understanding not only the Terraform code but also how AWS services interact with each other behind the scenes.

One of my biggest learnings was understanding the complete traffic flow from a user request all the way to an ECS task.

---

# Understanding the Request Flow

Initially, I knew how to create resources using Terraform, but I wanted to understand how every component fits together.

The final request flow looks like:

```text
User
 ↓
Route53
 ↓
ALB
 ↓
Listener
 ↓
Target Group
 ↓
Frontend ECS Task
 ↓
Service Connect
 ↓
Backend ECS Task
```

The ALB acts as the entry point for external traffic.

The listener receives requests and forwards them to a target group.

The target group maintains a list of healthy ECS tasks.

The frontend ECS task receives the request and communicates with the backend ECS task through Service Connect.

---

# Understanding ECS Task Definitions

One important realization was that a Task Definition is only a blueprint.

It defines:

* Container Image
* CPU
* Memory
* Port Mapping
* Environment Variables
* Logging Configuration

However, a Task Definition does not run anything.

The ECS Service is responsible for launching and maintaining the actual tasks.

---

# Understanding ECS Service

The ECS Service uses the Task Definition and creates running tasks.

It also ensures the desired number of tasks are always running.

If a task crashes:

```text
ECS Service
      ↓
Detect Failure
      ↓
Launch New Task
```

This was an important concept because it showed me the difference between a blueprint (Task Definition) and a running workload (Service).

---

# Understanding Dynamic Load Balancer Configuration

One of the most valuable learnings was understanding the purpose of the ECS Load Balancer block.

Initially, I thought it was creating the ALB.

Later, I understood that:

```text
ALB
Target Group
Listener
```

already exist.

The purpose of the ECS Load Balancer block is to register ECS tasks into the target group.

Example:

```text
Frontend Task
IP = 10.0.3.15
Port = 80
```

ECS automatically registers:

```text
10.0.3.15:80
```

inside the target group.

This is how traffic eventually reaches the frontend container.

---

# Understanding Service Connect

Another major learning was Service Connect.

Instead of using private IP addresses, services communicate using DNS names.

Example:

```text
Frontend
    ↓
backend:8000
    ↓
Backend
```

Benefits:

* No hardcoded IP addresses
* Easier scaling
* Simpler service discovery
* Better maintainability

This significantly simplifies communication between ECS services.

---

# Understanding Network Configuration

The ECS Network Configuration is responsible for:

* Subnet placement
* Security Groups
* Public IP assignment

It is not related to ALB configuration.

Its purpose is to determine where ECS tasks run and how they are protected.

Example:

```text
Frontend Task
      ↓
Private Subnet
      ↓
Frontend Security Group
```

---

# Understanding Security Groups

Security Groups act as virtual firewalls.

They control:

```text
Who can talk to whom
```

Examples:

```text
ALB
 ↓
Frontend ECS

Frontend ECS
 ↓
Backend ECS

Backend ECS
 ↓
Database
```

Each layer should only allow the minimum required communication.

This follows the principle of least privilege.

---

# Understanding CloudWatch Logs

CloudWatch Logs are essential for troubleshooting.

Every ECS service sends logs to CloudWatch.

Benefits:

* Startup debugging
* Runtime troubleshooting
* Application monitoring
* Error investigation

Without logs, diagnosing issues becomes significantly harder.

---

# Understanding IAM Roles

I learned that ECS requires IAM permissions to interact with AWS services.

The ECS Execution Role allows ECS to:

* Pull images from ECR
* Push logs to CloudWatch
* Read Secrets Manager
* Read Parameter Store

Without these permissions, ECS tasks would fail to start correctly.

---

# Additional Reflections and Learnings

## 1. Understanding Terraform Dependency Cycles

One of the most important lessons learned was understanding how Terraform builds a dependency graph before creating resources.

Initially, I attempted to use ECR repository URLs inside my local service definitions while simultaneously using those same local definitions to create the ECR repositories.

Example:

```hcl
locals {
  ecs_services = [
    {
      image = aws_ecr_repository.ecr_repositories["backend"].repository_url
    }
  ]
}

resource "aws_ecr_repository" "ecr_repositories" {
  for_each = local.ecs_services_map
}
```

This created a circular dependency:

```text
locals
   ↓
ECR Repositories
   ↓
locals
```

Terraform could not determine which resource should be evaluated first.

### Learning

Terraform evaluates dependencies before creating resources.

A resource cannot depend on a local value that itself depends on that resource.

The fix was to build image references using variables and predictable naming conventions rather than referencing the ECR resource itself.

---

## 2. Converting List of Objects into Maps

Initially, ECS services were defined as a list of objects.

Example:

```hcl
[
  {
    name = "backend"
  },
  {
    name = "frontend"
  }
]
```

To make resource creation easier and more maintainable, the list was converted into a map.

```hcl
ecs_services_map = {
  for service in local.ecs_services :
  service.name => service
}
```

### Learning

Terraform resources using `for_each` work best with maps because:

* Stable resource addressing
* Easier iteration
* Access to `each.key`
* Easier future scaling

This became the foundation of the dynamic infrastructure design.

---

## 3. Dynamic Resource Creation Pattern

A major design improvement was creating a single source of truth for service configurations.

Instead of hardcoding multiple ECS resources individually, all service-specific configurations were maintained inside locals and tfvars.

Benefits:

* Easier maintenance
* Easier scaling
* Consistent configuration
* Reduced duplication

Adding a new service now requires minimal code changes.

---

## 4. Understanding Dynamic Blocks

Dynamic blocks were used for ECS Load Balancer configuration.

Example:

```hcl
dynamic "load_balancer" {
  for_each = each.value.need_alb ? [1] : []

  content {
    ...
  }
}
```

### Learning

Terraform requires a collection for iteration.

The expression:

```hcl
[1]
```

creates a list with one element.

```hcl
[]
```

creates an empty list.

If `need_alb` is true:

```text
load_balancer block is created
```

If false:

```text
load_balancer block is skipped
```

This allows optional resource configuration without duplicating code.

---

## 5. Understanding ECS Service Connect

Initially it was unclear how frontend services communicate with backend services.

Service Connect solved this problem.

Example:

```text
frontend
    │
    ▼
backend:8000
```

### Learning

Service Connect provides:

* Internal DNS resolution
* Service discovery
* Service-to-service communication
* No hardcoded IP addresses

This greatly simplifies microservice communication.

---

## 6. Understanding ECS Load Balancer Registration

Initially I thought the ALB directly communicates with ECS Services.

After deeper investigation, I learned the actual flow is:

```text
ALB
   │
   ▼
Target Group
   │
   ▼
Task IP + Container Port
   │
   ▼
ECS Task
```

The ECS Service dynamically registers task IPs into the Target Group.

The ALB never communicates directly with ECS Services.

It communicates only with Target Group members.

---

## 7. Fargate CPU and Memory Constraints

While creating ECS Task Definitions, Terraform failed with:

```text
No Fargate configuration exists for given values
```

Example:

```text
CPU    = 1024
Memory = 1024
```

### Learning

Fargate supports only specific CPU and Memory combinations.

Not every CPU value can be paired with every memory value.

Always validate supported Fargate combinations before deployment.

---

## 8. ECR Naming Restrictions

While creating ECR repositories, deployment failed because repository names contained uppercase characters.

Example:

```text
DevopsDojo-dev-backend
```

### Learning

ECR repository names must be lowercase.

Valid:

```text
devopsdojo-dev-backend
```

Invalid:

```text
DevopsDojo-dev-backend
```

AWS service naming restrictions should always be reviewed before implementation.

---

## 9. Mutable vs Immutable Image Tags

I learned how ECR manages image tags.

### Mutable

Allows overwriting tags:

```text
latest → V1
latest → V2
```

### Immutable

Prevents overwriting existing tags.

```text
v1.0.0 → V1
v1.0.0 → Cannot overwrite
```

### Learning

Since GitHub Actions pushes both:

```text
latest
commit-sha
```

using Mutable repositories makes sense for development environments.

---

## 10. Terraform State and Resource Naming

Changing values used in resource names can cause Terraform to recreate resources.

Example:

```hcl
project = "DevopsDojo"
```

Changing to:

```hcl
project = "devopsdojo"
```

may force resource replacement for services whose names depend on that variable.

### Learning

Always review Terraform plans carefully before applying naming convention changes.

Resource names often become part of the infrastructure identity.

---

# Understanding Secrets Manager Design

Initially, I stored a complete database connection string directly inside Secrets Manager.

Example:

```text
postgresql://user:password@host:port/database
```

Later I understood that a production-grade approach is storing secrets as structured JSON.

Example:

```json
{
  "username": "postgres",
  "password": "password",
  "host": "endpoint",
  "port": 5432,
  "database": "mydb"
}
```

Benefits:

* Easier secret rotation
* Easier secret management
* Easier application integration
* More flexible architecture

---

# Understanding RDS and Aurora Differences

I learned that RDS and Aurora solve different problems.

### RDS PostgreSQL

Used for:

* Development environments
* Lower cost
* Simpler workloads

### Aurora PostgreSQL

Used for:

* Production environments
* High availability
* Read scaling
* Automatic failover

Aurora provides:

* Writer node
* Multiple reader nodes
* Shared storage architecture

This makes Aurora more suitable for production workloads.

---

# Understanding Database Configuration Consistency

A valuable lesson learned was ensuring database naming consistency.

The database name used by:

* Backend Service
* RDS Instance
* Aurora Cluster

must remain aligned.

Example:

```text
mydb
```

Using different database names across components can lead to application connection failures.

Single source of truth should always be maintained through Terraform variables.

---

---

# Phase 2 - GitHub Actions, ECS Deployment & Troubleshooting Learnings

While implementing the CI/CD pipelines for the DevOps Dojo project, I encountered several real-world deployment issues. Instead of simply fixing them, I focused on understanding why they occurred and how production systems behave internally.

This phase significantly improved my understanding of ECS, ECR, Terraform, GitHub Actions, and deployment workflows.

---

# Understanding Infrastructure vs Application Pipelines

Initially, I thought infrastructure creation and application deployment should happen in a single pipeline.

After implementing both pipelines, I realized they serve different purposes.

## Infrastructure Pipeline

Responsible for:

- Creating AWS Resources
- Updating Infrastructure
- Destroying Infrastructure

Example:

```text
Terraform
      │
      ▼
AWS Infrastructure
```

---

## Application Pipeline

Responsible for:

- Building Docker Images
- Pushing Images to ECR
- Running Database Migrations
- Updating ECS Task Definitions
- Deploying ECS Services

Example:

```text
GitHub Actions
        │
        ▼
Docker Build
        │
        ▼
Amazon ECR
        │
        ▼
Amazon ECS
```

### Learning

Infrastructure changes happen occasionally.

Application deployments happen multiple times every day.

Keeping them separate improves maintainability and deployment speed.

---

# Understanding ECS Task Definitions

One of the biggest realizations was understanding that ECS Task Definitions are only blueprints.

They contain information such as:

- Container Image
- CPU
- Memory
- Environment Variables
- Port Mapping

However, they never communicate with Amazon ECR.

Example:

```text
Task Definition

Image:
devopsdojo-dev-backend:latest
```

This is simply stored as metadata.

Terraform successfully creates the Task Definition even if that image does not exist.

---

# Understanding When ECS Contacts Amazon ECR

Initially I assumed ECS verifies the Docker image while creating the infrastructure.

Later I learned that ECS only contacts Amazon ECR when a task is started.

Flow:

```text
Task Definition Created
        │
        ▼
No Image Validation
        │
        ▼
Run ECS Task
        │
        ▼
Pull Image From ECR
```

Only during task startup does ECS attempt to pull the image.

---

# Understanding CannotPullContainerError

One of the first production-style issues I encountered was:

```text
CannotPullContainerError
```

Initially I thought ECS itself had failed.

After investigation I learned that ECS was working correctly.

The actual issue was that the Task Definition referenced an incorrect image.

Example:

```text
devopsdojo-dev:latest
```

instead of

```text
devopsdojo-dev-backend:latest
```

Since that repository did not exist, ECS could not pull the image.

### Learning

Whenever I see:

```text
CannotPullContainerError
```

my first troubleshooting steps are:

- Verify the ECR repository exists.
- Verify the repository name is correct.
- Verify the image tag exists.

---

# Understanding Image Not Found Errors

Another important learning was distinguishing between two similar errors.

## Repository Not Found

```text
CannotPullContainerError
```

Usually indicates:

- Incorrect repository name
- Repository deleted
- Wrong AWS account
- Wrong region

---

## Image Not Found

Repository exists.

But:

```text
latest
```

or

```text
commit-sha
```

does not exist.

### Learning

Repository issues and image tag issues are different problems and should be investigated separately.

---

# Understanding First-Time ECS Deployment

One question I had was:

How can Terraform successfully create ECS resources when no Docker images exist yet?

The answer became clear after understanding Task Definitions.

Flow:

```text
Terraform
        │
        ▼
Create ECR Repository
        │
        ▼
Create ECS Task Definition
        │
        ▼
No Image Validation
```

Only when ECS launches a task does it attempt to pull the image.

This explains why infrastructure creation succeeds even before any Docker image is pushed.

---

# Understanding Database Migration Tasks

Initially I believed my migration task was running against the newest application image.

After deeper analysis I realized:

The migration task launches using the current ECS Task Definition.

If the Task Definition still points to an old image, the migration also runs using that old image.

Example:

```text
Task Definition
        │
        ▼
Old Image
        │
        ▼
Migration Task
```

### Learning

If migrations depend on new application code, the Task Definition must first reference the new image.

Otherwise the migration may execute outdated code.

This helped me understand why many enterprise deployment pipelines update the Task Definition before executing migrations or use dedicated migration images.

---

# Understanding Terraform Outputs

Initially I hardcoded:

- Security Group IDs
- Subnet IDs

inside GitHub Actions.

Later I learned Terraform Outputs provide these values dynamically.

Example:

```bash
terraform output
```

returned:

- Backend Security Group
- Frontend Security Group
- Private Subnets
- VPC ID

### Learning

Infrastructure should expose important resource IDs through outputs instead of relying on hardcoded values.

This makes deployments more reusable and maintainable.

---

# Understanding Circular Dependencies

While trying to improve my Terraform design, I introduced a dependency cycle.

Example:

```text
locals
      │
      ▼
ECR Repository
      │
      ▼
locals
```

Terraform reported:

```text
Cycle detected
```

### Learning

Terraform builds a dependency graph before creating resources.

Resources cannot depend on values that themselves depend on those resources.

Breaking this circular dependency was one of the most valuable Terraform lessons in this project.

---

# Understanding ECR Repository Deletion

During cleanup I received:

```text
RepositoryNotEmptyException
```

Terraform could not delete the repository because Docker images were still stored inside it.

### Learning

Amazon ECR will not delete non-empty repositories unless:

- Images are deleted first, or
- force_delete is configured correctly.

This reinforced the importance of understanding AWS resource lifecycle during infrastructure destruction.

---

# Key Reflection

The biggest improvement during this phase was shifting my mindset.

Initially, I focused on writing Terraform and GitHub Actions.

Now, I focus on understanding:

- How AWS services communicate
- Why deployments fail
- How Terraform evaluates dependencies
- How ECS launches containers
- How ECR stores images
- How GitHub Actions orchestrates deployments

Instead of memorizing commands, I now try to understand the complete lifecycle of every deployment.

This troubleshooting-first approach has significantly improved my confidence in designing, deploying, and debugging cloud infrastructure.

---

# Performance Testing Reflections

## Scenario

I deployed a quiz application on AWS using the following architecture:

```
k6
 │
 ▼
Route53
 │
 ▼
Application Load Balancer
 │
 ▼
ECS Service (1 Backend Task)
 │
 ▼
RDS
```

The objective was to understand how the application behaves under concurrent users and identify the first infrastructure bottleneck.

---

# Observations

## Smoke Test

Results:

- Application reachable
- Complete quiz journey successful
- All API validations passed
- No HTTP failures
- P95 response time well within threshold

Conclusion:

The application was healthy and ready for performance testing.

---

## Load Test

Results:

- 50 Virtual Users
- 4300 HTTP Requests
- 1075 Quiz Journeys
- HTTP Failures = 0%
- No 5XX Errors
- P95 Response Time = 3.48 seconds

Although every request completed successfully, the response time increased significantly under load.

---

# Infrastructure Analysis

## ECS Metrics

Observed:

- CPU Utilization increased from approximately 3% to nearly 100%.
- Memory Utilization remained around 19%.

Conclusion:

The backend container exhausted its CPU resources but did not experience memory pressure.

---

## ALB Metrics

Observed:

- Request Count increased as expected.
- Target Response Time increased from approximately 105 ms to around 2.8 seconds.
- No Target 5XX Errors.

Conclusion:

The ALB was functioning correctly. Increased response time was caused by the backend taking longer to process requests.

---

## CloudWatch Logs

Observed:

- No application exceptions.
- No database errors.
- No HTTP 500 responses.

Conclusion:

The application remained stable throughout the load test.

---

# Bottleneck

The performance bottleneck was the ECS backend task.

Evidence:

- CPU reached nearly 100%.
- Memory remained stable.
- Response time increased significantly.
- No request failures occurred.

Conclusion:

The backend became **CPU-bound**, not memory-bound.

---

# Key Learning

A system can remain healthy while becoming slower.

High CPU utilization does **not** automatically mean the application will return 500 errors.

Instead, users may simply experience increased response times.

---

# Interview Question

## Q: How did you identify the bottleneck?

**Answer:**

I executed a k6 load test against my application deployed on AWS ECS behind an Application Load Balancer. During the test, I monitored CloudWatch Container Insights, ALB metrics, and CloudWatch Logs simultaneously.

Container Insights showed CPU utilization increasing from around 3% to nearly 100%, while memory utilization remained stable at approximately 19%. At the same time, the ALB Target Response Time increased from about 105 ms to nearly 2.8 seconds. Despite the increased latency, there were no HTTP failures or 5XX responses, and CloudWatch Logs showed no application exceptions.

Based on these observations, I concluded that the backend ECS task had become CPU-bound. The application remained stable and continued serving requests, but response times increased because the single ECS task had exhausted its available CPU capacity.

---

## Q: Why were there no 500 errors even though CPU reached 100%?

**Answer:**

High CPU utilization does not necessarily cause application failures. In this case, the backend still had enough resources to process every request, but it required more time to do so. As a result, response times increased while all requests continued to complete successfully.

---

## Q: Why did response time increase?

**Answer:**

The backend container became CPU-bound. Since only one ECS task was processing all incoming requests, the application required more time to complete each request as concurrency increased. This caused the ALB Target Response Time and k6 response times to increase.

---

## Q: Why wasn't memory the bottleneck?

**Answer:**

CloudWatch Container Insights showed memory utilization remained almost constant throughout the test, while CPU utilization increased dramatically. This indicates the workload required additional processing power rather than additional memory.

---

## Q: What would you improve next?

**Answer:**

The next improvements would be:

- Increase ECS task CPU allocation.
- Enable ECS Service Auto Scaling.
- Compare performance before and after scaling.
- Optimize CPU-intensive application logic if necessary.
- Configure CloudWatch Dashboards and Alarms for proactive monitoring.

---

# Final Reflection

This exercise demonstrated the complete performance testing workflow:

- Deploy application to AWS.
- Validate functionality using a smoke test.
- Execute a load test using k6.
- Monitor ECS, ALB, and CloudWatch simultaneously.
- Correlate infrastructure metrics with application performance.
- Identify the system bottleneck.
- Recommend scaling and optimization strategies based on evidence.

The most important lesson was learning to correlate **k6 metrics**, **CloudWatch Container Insights**, **ALB metrics**, and **application logs** to accurately diagnose performance issues instead of relying on a single metric.

---

# Personal Reflection

The most important lesson from this project was moving beyond simply writing Terraform code and learning how infrastructure components interact with each other.

The biggest learning from this development was understanding how to design reusable Terraform modules while keeping the infrastructure dynamic enough to support multiple environments from a single codebase.

I gained hands-on experience in:

* Terraform module design
* Dynamic infrastructure creation
* Dependency management
* ECS architecture
* Service discovery
* Load balancing
* Secrets management
* Database architecture
* AWS networking
* Terraform state management

Most importantly, I learned how to reason about infrastructure rather than simply provisioning resources.
