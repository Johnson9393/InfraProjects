# Terraform Dynamic Design - DevOps Dojo

## Overview

One of the primary goals of this project was not only to provision AWS infrastructure, but also to design Terraform code in a reusable, scalable, and maintainable way.

Instead of creating separate Terraform code for every environment and every service, I focused on building a single source of truth that can be reused across multiple environments.

The objective was:

```text
Write Once
Deploy Anywhere
```

Examples:

```text
Dev Environment
QA Environment
Stage Environment
Prod Environment
```

All environments use the same Terraform code.

Only the input values change.

---

# Design Philosophy

Instead of creating:

```text
dev/
  vpc.tf
  ecs.tf

prod/
  vpc.tf
  ecs.tf
```

I decided to maintain:

```text
Single Terraform Codebase
        +
Environment Specific Variables
```

This reduces:

* Code duplication
* Maintenance effort
* Human errors

---

# High-Level Design

```text
variables.tf
      ↓
dev.tfvars / prod.tfvars
      ↓
locals.tf
      ↓
Terraform Resources
      ↓
AWS Infrastructure
```

This is the foundation of the entire project.

---

# Understanding variables.tf

Variables define the input contract of the infrastructure.

Think of variables as:

```text
Questions asked by Terraform
```

Example:

```hcl
variable "environment" {
  type = string
}
```

Terraform is asking:

```text
Which environment should I deploy?
```

---

Example:

```hcl
variable "frontend" {
  type = object({
    image     = string
    port      = number
    cpu       = number
    memory    = number
  })
}
```

Terraform is asking:

```text
What should the frontend service look like?
```

Variables define structure, not values.

---

# Understanding dev.tfvars

The actual values are stored in environment-specific files.

Example:

```hcl
environment = "dev"

frontend = {
  image  = "frontend:latest"
  port   = 80
  cpu    = 1024
  memory = 1024
}
```

Think of tfvars as:

```text
Answers to Terraform Questions
```

variables.tf:

```text
What is the environment?
```

dev.tfvars:

```text
environment = dev
```

---

# Why Use tfvars?

Without tfvars:

```hcl
environment = "dev"
```

would be hardcoded inside resources.

Changing environments becomes difficult.

With tfvars:

```text
Same Code
Different Inputs
```

Example:

```bash
terraform plan -var-file=vars/dev.tfvars
```

```bash
terraform plan -var-file=vars/prod.tfvars
```

Same code.

Different infrastructure.

---

# Understanding Locals

Locals are internal Terraform variables.

Think of locals as:

```text
Transformation Layer
```

between:

```text
Input Values
        ↓
AWS Resources
```

---

Example:

Input:

```hcl
frontend = {
  port = 80
}
```

Local:

```hcl
merge(
  var.frontend,
  {
    name = "frontend-service"
  }
)
```

Result:

```hcl
{
  name = "frontend-service"
  port = 80
}
```

---

# Why Use Locals?

Locals help:

* Combine variables
* Generate naming conventions
* Reduce duplication
* Create reusable structures

Without locals:

```hcl
name = "${var.prefix}-${var.environment}-frontend-service"
```

would be repeated everywhere.

With locals:

```hcl
local.ecs_services
```

contains everything in one place.

---

# Understanding merge()

One of the most useful Terraform functions used in this project is:

```hcl
merge()
```

Example:

```hcl
merge(
  var.frontend,
  {
    name = "frontend-service"
  }
)
```

Result:

```hcl
{
  image = "frontend:latest"
  port  = 80
  name  = "frontend-service"
}
```

This allows me to enrich data before creating resources.

---

# Understanding ecs_services

Instead of creating:

```hcl
frontend_service
backend_service
```

separately,

I created:

```hcl
local.ecs_services
```

Example:

```text
[
  frontend-service,
  backend-service
]
```

This becomes the single source of truth for all ECS services.

---

# Understanding ecs_services_map

Terraform works best with maps when using for_each.

Example:

```hcl
ecs_services_map = {
  for service in local.ecs_services :
  service.name => service
}
```

Result:

```hcl
{
  frontend-service = {...}
  backend-service  = {...}
}
```

This makes iteration easier.

---

# Understanding for_each

for_each allows Terraform to create multiple resources dynamically.

Example:

```hcl
resource "aws_ecs_service" "dojo_service" {
  for_each = local.ecs_services_map
}
```

Terraform automatically creates:

```text
Frontend Service
Backend Service
```

without duplicating code.

---

Without for_each:

```hcl
resource "aws_ecs_service" "frontend" {}

resource "aws_ecs_service" "backend" {}
```

More code.

More maintenance.

More duplication.

---

# Understanding each.key and each.value

Example:

```hcl
{
  frontend-service = {...}
  backend-service  = {...}
}
```

During iteration:

```hcl
each.key
```

becomes:

```text
frontend-service
```

or

```text
backend-service
```

---

Example:

```hcl
each.value.port
```

returns:

```text
80
```

or

```text
8000
```

depending on the service.

---

# Understanding Dynamic Blocks

Dynamic blocks allow Terraform to create nested blocks conditionally.

Example:

```hcl
dynamic "load_balancer" {
  for_each = each.value.need_alb ? [1] : []
}
```

Frontend:

```text
need_alb = true
```

Result:

```text
Load Balancer Block Created
```

Backend:

```text
need_alb = false
```

Result:

```text
Load Balancer Block Skipped
```

---

# Understanding Modules

The VPC was built as a reusable module.

Benefits:

* Reusability
* Separation of concerns
* Cleaner root configuration
* Easier maintenance

Example:

```hcl
module "network" {
  source = "./modules/network"
}
```

The module handles:

* VPC
* Subnets
* Route Tables
* Internet Gateway
* NAT Gateway

without exposing implementation details.

---

# Multi Environment Design

One codebase supports:

```text
Dev
QA
Stage
Prod
```

Only the inputs change.

Example:

```bash
terraform plan \
-var-file=vars/dev.tfvars
```

or

```bash
terraform plan \
-var-file=vars/prod.tfvars
```

The infrastructure adapts automatically.

---

# Benefits of This Design

## Reusability

Same Terraform code can be reused everywhere.

---

## Scalability

New ECS services can be added without creating new resource blocks.

Example:

```text
Frontend
Backend
Auth
Payments
Notifications
```

can all use the same Terraform logic.

---

## Maintainability

Most changes happen in:

```text
dev.tfvars
prod.tfvars
```

instead of modifying Terraform resources.

---

## Single Source of Truth

Service configuration exists in one place.

This reduces inconsistencies.

---

# Key Takeaways

1. Variables define the contract.
2. tfvars provide environment-specific values.
3. Locals transform and enrich data.
4. merge() combines structures.
5. for_each creates resources dynamically.
6. Dynamic blocks create optional configurations.
7. Modules improve reusability.
8. Same Terraform code can support multiple environments.
9. Infrastructure becomes easier to scale and maintain.
10. Terraform should be designed as a platform, not just a collection of resource files.

---

# Final Mental Model

```text
variables.tf
       ↓
dev.tfvars / prod.tfvars
       ↓
locals.tf
       ↓
for_each / dynamic blocks
       ↓
Terraform Resources
       ↓
AWS Infrastructure
```

The biggest learning from this project is that Terraform is not just Infrastructure as Code.

It is also about designing reusable, scalable, and maintainable infrastructure patterns.
