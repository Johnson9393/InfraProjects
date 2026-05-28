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


