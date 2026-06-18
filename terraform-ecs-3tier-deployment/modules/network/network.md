# Network Module

## Overview

This Terraform Network Module provides a reusable and configurable AWS networking foundation that can be used across multiple environments such as Development, QA, Staging, and Production.

The module dynamically creates VPC networking components based on input variables, allowing different environments to use different networking configurations without changing the module code.

The primary goal of this module is to standardize network provisioning, reduce code duplication, and support environment-specific requirements through simple variable-driven configurations.

---

# Architecture Components

This module provisions the following AWS networking resources:

* VPC
* Public Subnets
* Private Subnets
* Internet Gateway
* Public Route Table
* Public Route Table Associations
* Elastic IPs (Optional)
* NAT Gateways (Optional)
* Private Route Tables
* Private Route Table Associations
* NAT Gateway Routes (Optional)

---

# Design Goals

### Reusable

The same module can be used by multiple projects and environments without modifying the module code.

### Dynamic

Resources are created only when required based on input variables.

### Cost Optimized

Development environments can use a single NAT Gateway while Production environments can use multiple NAT Gateways for high availability.

### Environment Agnostic

The module does not contain environment-specific values. All values are passed through variables.

### Modular

Networking is separated from application resources, making the infrastructure easier to maintain and scale.

---

# Networking Design

## Public Subnets

Public subnets are created based on the provided subnet definitions.

These subnets:

* Receive public IPs automatically.
* Are associated with the public route table.
* Have internet access through the Internet Gateway.

---

## Private Subnets

Private subnets are created based on the provided subnet definitions.

These subnets:

* Do not receive public IPs.
* Are associated with private route tables.
* Can optionally access the internet through NAT Gateways.

---

## Internet Gateway

A single Internet Gateway is attached to the VPC.

Purpose:

* Provides internet connectivity for public subnets.
* Allows public-facing resources such as Load Balancers and Bastion Hosts to communicate with the internet.

---

## NAT Gateway

The module supports three deployment patterns.

### Pattern 1 - No NAT Gateway

Used for:

* Isolated workloads
* Internal services
* Cost-sensitive environments

Resources created:

* No EIP
* No NAT Gateway
* One Private Route Table
* No internet route for private subnets

---

### Pattern 2 - Single NAT Gateway

Used for:

* Development
* QA
* Small environments

Resources created:

* One EIP
* One NAT Gateway
* One Private Route Table
* All private subnets share the same NAT Gateway

Benefits:

* Lower AWS cost
* Simpler architecture

---

### Pattern 3 - Multiple NAT Gateways

Used for:

* Production
* High Availability environments

Resources created:

* One NAT Gateway per public subnet
* One EIP per NAT Gateway
* One Private Route Table per NAT Gateway
* Private subnets distributed across route tables

Benefits:

* High availability
* Reduced cross-AZ dependency
* Better fault tolerance

---

# Module Logic

The module dynamically determines the number of NAT Gateways and route tables using the following variables:

```hcl
need_ngw
need_single_ngw
```

### Example

```hcl
need_ngw = false
```

Result:

* No NAT Gateway
* No EIP
* One Private Route Table

---

```hcl
need_ngw = true
need_single_ngw = true
```

Result:

* One NAT Gateway
* One EIP
* One Private Route Table

---

```hcl
need_ngw = true
need_single_ngw = false
```

Result:

* Multiple NAT Gateways
* Multiple EIPs
* Multiple Route Tables

---

# Why This Design?

### Flexibility

Different environments require different networking architectures.

For example:

* Dev may require only one NAT Gateway.
* Prod may require multiple NAT Gateways.

This module supports both scenarios without changing the module code.

---

### Cost Optimization

NAT Gateways are expensive resources.

Using a single NAT Gateway for lower environments significantly reduces AWS costs.

---

### Scalability

As environments grow, additional NAT Gateways and route tables can be created automatically using configuration changes only.

---

### Maintainability

All networking logic is centralized in a single reusable module.

Infrastructure teams can update networking standards in one place instead of multiple repositories.

---

# Example Usage

## Development Environment

```hcl
module "network" {

  source = "../../modules/network"

  vpc_name = "dev-vpc"
  vpc_cidr = "10.0.0.0/16"

  need_ngw        = true
  need_single_ngw = true

  public_subnets = [
    {
      cidr              = "10.0.1.0/24"
      availability_zone = "us-east-1a"
      prefix            = "public"
    },
    {
      cidr              = "10.0.2.0/24"
      availability_zone = "us-east-1b"
      prefix            = "public"
    }
  ]

  private_subnets = [
    {
      cidr              = "10.0.11.0/24"
      availability_zone = "us-east-1a"
      prefix            = "private"
    },
    {
      cidr              = "10.0.12.0/24"
      availability_zone = "us-east-1b"
      prefix            = "private"
    }
  ]
}
```

---

## Production Environment

```hcl
module "network" {

  source = "../../modules/network"

  vpc_name = "prod-vpc"
  vpc_cidr = "10.1.0.0/16"

  need_ngw        = true
  need_single_ngw = false

  public_subnets  = [...]
  private_subnets = [...]
}
```

This creates a highly available networking architecture with multiple NAT Gateways.

---

# Future Enhancements

Possible future improvements include:

* Dedicated Database Subnets
* Dedicated Database Route Tables
* VPC Endpoints
* Network ACL Support
* IPv6 Support
* Transit Gateway Integration
* AZ-based NAT Routing
* Flow Logs

---

# Summary

This module provides a reusable, scalable, and environment-aware AWS networking foundation.

By using configurable NAT Gateway deployment patterns, the same module can support both cost-optimized development environments and highly available production environments while maintaining a consistent architecture across projects.
