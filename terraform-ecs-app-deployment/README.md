# Terraform ECS App Deployment

This repository contains a production-style AWS infrastructure deployment project using Terraform and Amazon ECS Fargate.

The goal of this project is to deploy a containerized application on AWS using Infrastructure as Code (IaC) principles with Terraform.

---

# Current Folder Structure

```text id="v1m94h"
terraform-ecs-app-deployment/
├── about_me.yaml                  # warm-up
├── infra/
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── sg.tf
│   ├── rds.tf
│   ├── ecs.tf
│   ├── alb.tf
│   ├── route53.tf
│   ├── cloudwatch.tf
│   └── .gitignore
├── app/
│   └── src/                       # Your two-tier app code
├── .github/
│   └── workflows/
│       └── build-and-deploy.yml   
└── README.md
```

---

# Project Goal

This project will include:

* AWS VPC Infrastructure
* ECS Fargate Deployment
* Application Load Balancer
* PostgreSQL RDS
* Route53 DNS
* ACM SSL Certificate
* Amazon ECR
* GitHub Actions CI/CD
* Terraform Remote Backend

---

# Application Setup

The application source code has been copied into:

```text id="dd6d95"
app/src/
```

Required application files such as:

* Dockerfile
* requirements.txt
* docker-compose.yml
* config.py
* run.py

have also been added to the `app/` directory.

---

# Rules for every submission

* Never commit .terraform/, *.tfstate, *.tfstate.backup, or .env files — add them to .gitignore before your first push
* Run terraform fmt before committing any .tf file
* Run terraform validate before running terraform plan
* Always terraform destroy after testing to avoid unnecessary AWS charges
* Write a short commit message that describes what you did (e.g. add nat gateway and private route table)
* — update the README as you go

---

# Task 1 - YAML warm-up

Create a file called about_me.yaml in the root of the repo. This file demonstrates the three core YAML concepts 

## File must include:

* At least one dictionary (key-value pairs — name, city, role)
* At least one list (hobbies, tools you use, or skills)
* At least one nested structure (e.g. experience or education with sub-keys)

Validate the file with a YAML linter (yamllint or any online tool) before committing.

> **Why this matters:**
> While writing Github Actions workflows in YAML we will be comfortable with indentation and structure now will save a lot of debugging later. 

---

# Task 2 — Install Terraform and tfenv

Install tfenv and use it to manage Terraform versions.

```bash
## Mac
brew install tfenv

## WSL / Linux
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

## Install and Activate Terraform Version
tfenv install 1.12.1
tfenv use 1.12.1
terraform version
```
---

## Checklist:

* ✅ tfenv installed and working
* ✅ Terraform 1.12.1 active
* ✅ `terraform version` shows 1.12.1
---

# Task 3 - Create versions.tf and initialize the project

Create the infra/ folder. Inside it, create versions.tf with the Terraform and AWS provider version constraints.

```bash
terraform {
  required_version = "= 1.12.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}
```
Run terraform init and confirm the .terraform/ folder and lock file are created.

Add the following to infra/.gitignore:

```text
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
.terraform.lock.hcl
```
> **Note:** `.terraform.lock.hcl` is committed to the repository to maintain consistent Terraform provider versions across different environments and team members.


# Task 4 - Build the full VPC using Terraform

## Resources to create:

* VPC with enable_dns_hostnames = true and enable_dns_support = true
* 2 public subnets across two availability zones
* 2 private subnets across two availability zones
* 2 database subnets (separate CIDR range — keep RDS isolated)
* Create IGW and attach to vpc to access internet from public
* EIP and NAT for Private subnets to access internet
* Create public route table with route to IGW and associate with public subnets
* Create private route table with route to NGW and associate with private subnets

## Reference Flow:

```text
Public subnets  → Public route table  → Internet Gateway  → Internet
Private subnets → Private route table → NAT Gateway → Internet
DB subnets      → No outbound route   → VPC-internal only
```
## Commands to validate and apply VPC on aws

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```








