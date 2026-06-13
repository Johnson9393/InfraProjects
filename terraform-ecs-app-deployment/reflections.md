## Why is `provider.tf` used when Terraform can create resources without it?

### Question

I was able to create AWS resources without defining a `provider.tf` file. What is the purpose of `provider.tf` and when should it be used?

### Answer

Terraform can create AWS resources without an explicit `provider "aws"` block if AWS credentials and region are already configured through the AWS CLI or environment variables. In this case, Terraform automatically uses the default AWS provider configuration.

However, a `provider.tf` file is commonly used to explicitly configure the AWS provider. This provides several benefits:

* Defines the AWS region in code, ensuring consistency across environments.
* Configures default tags that are automatically applied to all supported resources.
* Supports role assumption for cross-account access.
* Enables multiple provider configurations using aliases for different AWS accounts or regions.

Example:

```hcl
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      managed_by = "terraform"
      project    = "bootcamp"
    }
  }
}
```

Although Terraform can work without a `provider.tf` file, using one improves maintainability, consistency, and makes the infrastructure configuration self-contained.

----

## Why does the Terraform state file remain in S3 after `terraform destroy`?

### Question

I configured an S3 backend for Terraform state storage. When I ran `terraform destroy`, all AWS resources such as the VPC were deleted, but the state file remained in the S3 bucket. Why was the state file not deleted?

### Answer

This is expected behavior. Terraform only destroys the infrastructure resources that it manages and tracks in the state file. The remote backend (S3 bucket and the state file stored within it) is not considered a managed resource unless it is explicitly defined as one in the Terraform configuration.

When `terraform destroy` is executed:

* Managed infrastructure resources (VPCs, subnets, route tables, security groups, etc.) are deleted.
* The Terraform state file remains in the S3 bucket.
* The S3 bucket used as the backend is not deleted.

The state file is retained because Terraform uses it as a record of the infrastructure it managed, even after the resources have been destroyed.

If the state file is no longer required, it must be removed manually, for example:

```bash id="a8m31v"
aws s3 rm s3://sp-state-bucket/infra/terraform.tfstate
```

### Key Learning

Terraform destroys infrastructure resources but does not automatically delete the remote backend or the state file stored in it. Backend resources must be managed and removed separately if required.

---

# Task 6 — Concept Questions

## 1. What is idempotency in Terraform and why does it matter for infrastructure?

**Answer:**
Idempotency means that running the same Terraform configuration multiple times produces the same result without creating duplicate resources. It is important because infrastructure can be applied repeatedly in a predictable and consistent manner, reducing configuration drift and human errors.

---

## 2. What is a Terraform state file? What happens if two people apply from the same repo simultaneously without state locking?

**Answer:**
A Terraform state file stores information about the infrastructure resources managed by Terraform and maps them to the configuration. If two people run `terraform apply` simultaneously without state locking, they may overwrite each other's changes, resulting in state corruption, resource conflicts, or inconsistent infrastructure.

---

## 3. What is the difference between a resource block and a data block? When would you use each?

**Answer:**
A resource block creates, updates, or deletes infrastructure managed by Terraform. A data block reads information about existing infrastructure without managing it. Resource blocks are used when provisioning new resources, while data blocks are used to reference existing resources such as VPCs, AMIs, or security groups.

---

## 4. What is implicit dependency? Give one example from your VPC code.

**Answer:**
An implicit dependency occurs when one resource references an attribute of another resource, causing Terraform to determine the correct creation order automatically. For example, a subnet that uses `aws_vpc.main.id` has an implicit dependency on the VPC, so Terraform creates the VPC before the subnet.

---

## 5. When would you choose a VPC endpoint over a NAT gateway? Consider both cost and security.

**Answer:**
A VPC endpoint is preferred when resources need to access AWS services such as S3 or DynamoDB without traversing the public internet. It is generally more secure because traffic remains within the AWS network and can be more cost-effective than routing all traffic through a NAT Gateway.

---

## 6. Why do we keep RDS subnets separate from private app subnets — what problem does it solve?

**Answer:**
Keeping RDS subnets separate from private application subnets provides better network isolation and security. It allows database resources to have dedicated routing and access controls, reducing the risk of accidental exposure and making infrastructure management easier as the environment grows.

---

## Why commit `.terraform.lock.hcl` to Git?

* The `.terraform.lock.hcl` file records the exact provider versions that Terraform selected during `terraform init`.
* When another developer clones the repository and runs `terraform init`, Terraform uses the versions recorded in the lock file to ensure everyone uses the same provider versions.

### What happens when provider versions change?

If the version constraint in `versions.tf` is updated, Terraform may not automatically upgrade to the newer provider version because the lock file still pins the previously selected version.

For example:

```hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = ">= 6.0.0"
  }
}
```

If the lock file contains AWS provider version `6.2.0`, Terraform will continue using `6.2.0` until:

```bash
terraform init -upgrade
```

is executed.

Running:

```bash
terraform init -upgrade
```

allows Terraform to select newer provider versions that satisfy the constraints and updates the `.terraform.lock.hcl` file accordingly.

### Why commit the lock file?

Committing the lock file ensures consistent provider versions across all developers and CI/CD pipelines. It prevents unexpected provider upgrades and reduces the risk of infrastructure behaving differently between environments.

> **Note**: Terraform doesn't usually "not allow" the upgrade. Rather, it keeps using the version recorded in the lock file until someone intentionally runs terraform init -upgrade and commits the updated lock file.

---

## Why Do We Push Two Tags to ECR?

During the GitHub Actions build process, the Docker image is pushed to ECR using two tags:

```text
student-portal:latest
student-portal:<commit-sha>
```

Example:

```text
student-portal:latest
student-portal:a1b2c3d
```

### Why Use a Commit SHA Tag?

The commit SHA uniquely identifies the exact version of the application code that was built.

Benefits:

* Every image is unique.
* Easy to identify which Git commit is deployed.
* Makes rollbacks simple if a deployment fails.
* Provides complete deployment traceability.

Example:

```text
student-portal:a1b2c3d
student-portal:b4c5d6e
student-portal:c7d8e9f
```

Each image represents a specific version of the application.

### Why Use the `latest` Tag?

The `latest` tag always points to the most recently built image.

Benefits:

* Easy for developers to pull and test the newest image.
* Convenient for development and debugging.
* No need to remember specific commit SHA values.

Example:

```text
student-portal:latest
```

### How This Helps During ECS Deployment

When GitHub Actions updates the ECS task definition, it should reference the image using the commit SHA tag:

```text
123456789012.dkr.ecr.us-east-1.amazonaws.com/student-portal:a1b2c3d
```

This ensures ECS deploys the exact image built during that workflow run.

Using commit SHA tags prevents situations where multiple deployments reference the same `latest` tag and accidentally pull the wrong image.

### Summary

* `latest` → Convenient for development and testing.
* `<commit-sha>` → Safe, traceable, and recommended for deployments.
* ECS deployments should use the commit SHA image to guarantee the correct application version is deployed.
* Keeping both tags provides convenience for developers and reliability for production deployments.

---

## Why Use Commit SHA Tags Instead of Only `latest`?

Every time code is pushed to the `main` branch, GitHub Actions builds a new Docker image and pushes it to ECR.

Example:

```text
Commit A → student-portal:a1b2c3d
Commit B → student-portal:b4c5d6e
Commit C → student-portal:c7d8e9f
```

ECR now contains:

```text
student-portal:a1b2c3d
student-portal:b4c5d6e
student-portal:c7d8e9f
student-portal:latest
```

The `latest` tag always points to the most recent image, while each commit SHA tag points to a specific version of the application.

### Real-World Scenario

Suppose three developers push code to the `main` branch:

```text
Developer 1 → a1b2c3d
Developer 2 → b4c5d6e
Developer 3 → c7d8e9f
```

The ECS service automatically deploys:

```text
student-portal:c7d8e9f
```

Later, a bug is discovered in commit `c7d8e9f`.

Instead of rebuilding the application, we can simply update the ECS task definition to use a previously known good image:

```text
student-portal:b4c5d6e
```

ECS will pull that exact image from ECR and deploy it.

### Why This Is Useful

* Every image version is preserved in ECR.
* We can deploy any previous commit without rebuilding the application.
* Rollbacks are fast and reliable.
* We always know exactly which code version is running in production.

### Summary
* ECS task definitions should reference the commit SHA image tag.
* If a deployment fails, we can quickly roll back by updating the task definition to a previously successful image tag.

---

# ECS Auto Scaling - Quick Reference

## 1. Target Tracking Scaling (Most Common)

### What it does

AWS automatically maintains a target metric value.

### Example

```text
Target CPU = 60%

CPU = 80%
↓
Add Tasks

CPU = 20%
↓
Remove Tasks
```

### Terraform

```hcl
policy_type = "TargetTrackingScaling"
```

### Common Metrics

```text
ECSServiceAverageCPUUtilization
ECSServiceAverageMemoryUtilization
ALBRequestCountPerTarget
```

### Real-world Use Cases

✅ Web Applications

```text
Student Portal
E-Commerce Website
Internal Company Portal
```

✅ Microservices

```text
User Service
Payment Service
Catalog Service
```

### When to Use

```text
80% of ECS workloads
Simple and AWS-managed
```

---

## 2. Step Scaling

### What it does

Scales by a fixed amount when CloudWatch Alarms trigger.

### Example

```text
Memory > 80%
↓
Add 1 Task

Memory > 90%
↓
Add 2 Tasks
```

### Terraform

```hcl
policy_type = "StepScaling"
```

### Requires

```text
CloudWatch Alarm
+
Scaling Policy
```

### Real-world Use Cases

✅ Traffic spikes

```text
Flash Sale
Black Friday
Product Launch
```

### When to Use

```text
Need precise control
Need different actions for different thresholds
```

---

## 3. Simple Scaling (Legacy)

### What it does

CloudWatch Alarm triggers a fixed scaling action.

### Example

```text
CPU > 80%
↓
Add 1 Task
```

### Real-world Use Cases

```text
Rarely used today
Mostly replaced by Step Scaling
```

### When to Use

```text
Avoid for new projects
```

---

## 4. Scheduled Scaling

### What it does

Scales at specific times.

### Example

```text
9 AM
↓
Scale to 4 Tasks

10 PM
↓
Scale to 1 Task
```

### Real-world Use Cases

✅ Office Applications

```text
HR Portal
Payroll System
Internal Dashboards
```

✅ Educational Platforms

```text
Morning Traffic Predictable
```

### When to Use

```text
Traffic pattern is predictable
```

---

## 5. Predictive Scaling

### What it does

AWS predicts future traffic using historical patterns.

### Example

```text
Every day 9 AM traffic increases
↓
AWS scales before traffic arrives
```

### Real-world Use Cases

✅ Enterprise Workloads

```text
Large E-commerce
Banking Systems
Streaming Platforms
```

### When to Use

```text
Predictable daily traffic
Large-scale environments
```

---

# Common Scaling Metrics

## CPU Utilization

```text
Metric:
ECSServiceAverageCPUUtilization
```

### Example

```text
CPU > 60%
↓
Scale Out

CPU < 60%
↓
Scale In
```

### Best For

```text
API Servers
Backend Services
Microservices
```

---

## Memory Utilization

```text
Metric:
ECSServiceAverageMemoryUtilization
```

### Example

```text
Memory > 70%
↓
Scale Out
```

### Best For

```text
Java Apps
Spring Boot Apps
Large Caches
```

---

## ALB Request Count

```text
Metric:
ALBRequestCountPerTarget
```

### Example

```text
1000 Requests/Target
↓
Add Tasks
```

### Best For

```text
Public Websites
High Traffic APIs
```

---

# Load Balancer, CDN, Auto Scaling & DDoS - Quick Reference

## Load Balancer (ALB)

### What it does

Distributes traffic across multiple application instances/tasks.

```text
Users
  ↓
ALB
  ↓
Task-1
Task-2
Task-3
```

### Benefits

* High Availability
* Fault Tolerance
* No single point of failure
* Health Checks

### Real-world Use Cases

```text
E-Commerce Website
Banking Application
Student Portal
Netflix
Amazon
```

---

# Auto Scaling

### What it does

Automatically adds/removes ECS tasks based on load.

```text
100 Users
↓
1 Task

1000 Users
↓
4 Tasks
```

### Benefits

* Better Performance
* Cost Optimization
* Handles Traffic Spikes

### Real-world Use Cases

```text
Black Friday Sale
Exam Results Day
Product Launch
```

---

# How ALB and Auto Scaling Work Together

```text
Users
  ↓
ALB
  ↓
Task-1
Task-2
```

Traffic increases:

```text
CPU > 60%
↓
Auto Scaling
↓
Task-3
Task-4
```

ALB automatically sends traffic to new tasks.

### Benefits

```text
No downtime
Automatic scaling
Automatic traffic distribution
```

---

# CDN (CloudFront)

### What it does

Caches content closer to users worldwide.

Without CDN:

```text
India User
↓
US Server
```

With CDN:

```text
India User
↓
CloudFront Edge Location
```

### Benefits

* Faster Website
* Lower Latency
* Reduced Server Load
* Global Reach

### Real-world Use Cases

```text
Netflix
YouTube
Instagram
Amazon
```

---

# How CDN + ALB + Auto Scaling Work Together

```text
User
  ↓
CloudFront
  ↓
ALB
  ↓
ECS Tasks
```

### Flow

```text
Static Content
↓
Served by CloudFront Cache

Dynamic Requests
↓
Forwarded to ALB

Traffic Increase
↓
Auto Scaling Adds Tasks
```

### Production Architecture

```text
Users
   ↓
CloudFront
   ↓
ALB
   ↓
ECS Service
   ↓
RDS
```

---

# DDoS Attack

### What it is

Attackers send huge amounts of fake traffic.

```text
Millions of Requests
↓
Website Crash
```

### Common Types

```text
HTTP Flood
SYN Flood
UDP Flood
Bot Traffic
```

---

# AWS DDoS Protection

## AWS Shield Standard (Free)

Enabled automatically.

Protects against:

```text
Network Layer Attacks
Transport Layer Attacks
```

### Good For

```text
Personal Projects
Small Applications
```

---

## AWS Shield Advanced (Paid)

Additional protection.

Features:

```text
Advanced Detection
DDoS Response Team
Cost Protection
```

### Good For

```text
Banking Apps
E-Commerce
Enterprise Systems
```

---

# AWS WAF (Web Application Firewall)

Filters malicious requests.

Examples:

```text
Block SQL Injection
Block XSS
Block Bad Bots
Rate Limiting
Geo Blocking
```

### Example

```text
IP sends 5000 requests/min
↓
WAF Blocks IP
```

---

# Production Security Architecture

```text
Users
   ↓
CloudFront
   ↓
AWS Shield
   ↓
AWS WAF
   ↓
ALB
   ↓
ECS Tasks
   ↓
RDS
```

---

# What to Use for Student Portal

### Learning Environment

```text
ALB
+
ECS Auto Scaling
+
CloudFront
+
AWS Shield Standard
```

### Production Environment

```text
CloudFront
+
AWS Shield
+
AWS WAF
+
ALB
+
ECS Auto Scaling
+
RDS
```

---

# Interview Summary

## Load Balancer

```text
Distributes traffic across multiple servers/tasks.
```

## Auto Scaling

```text
Automatically increases/decreases capacity based on load.
```

## CDN

```text
Caches content closer to users for faster delivery.
```

## AWS Shield

```text
Protects against DDoS attacks.
```

## AWS WAF

```text
Protects against malicious web requests.
```

## Typical Production Flow

```text
CloudFront
↓
WAF
↓
ALB
↓
Auto Scaling ECS Tasks
↓
RDS
```
---