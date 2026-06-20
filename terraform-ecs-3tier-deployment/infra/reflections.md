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






# Personal Reflection

The biggest learning from this development was understanding how to design reusable Terraform modules while keeping the infrastructure dynamic enough to support multiple environments from a single codebase.

I also gained a deeper understanding of Terraform state management, tagging strategies, module design, resource naming conventions, validation blocks, and dynamic infrastructure creation using count expressions.
