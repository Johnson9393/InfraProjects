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

# Module Validation

The Network Module has been tested successfully using environment-specific variables.

Validated resources:

* VPC
* Public Subnets
* Private Subnets
* RDS Subnets
* Internet Gateway
* NAT Gateway
* Route Tables
* Route Associations
* Elastic IPs

All resources were created and destroyed successfully.

---




