# AgileOps Portal

## Overview

**AgileOps Portal** is a cloud-native DevOps project that demonstrates how to design, containerize, deploy, and manage a modern web application on **Amazon EKS (Elastic Kubernetes Service)** using industry-standard DevOps practices.

The project focuses on building a complete end-to-end deployment pipeline, covering infrastructure provisioning, container orchestration, CI/CD automation, monitoring, observability, security, and application lifecycle management.

The application itself provides an Agile collaboration platform featuring sprint retrospectives, team management, and Jira-style ticket tracking, while the primary goal of this repository is to showcase production-style Kubernetes and AWS DevOps implementation.

---

# Project Objectives

The purpose of this project is to demonstrate how a real-world application can be deployed and managed on Kubernetes using AWS cloud services and DevOps best practices.

This repository covers:

* Infrastructure provisioning using Terraform
* Containerization using Docker
* Kubernetes deployments on Amazon EKS
* CI/CD automation using GitHub Actions
* Application deployment using Kubernetes manifests
* Ingress and Load Balancer configuration
* Secrets and ConfigMap management
* Monitoring and observability
* Secure application deployment
* Rolling updates and application scaling
* Production-ready Kubernetes practices

---

# Technology Stack

### Cloud

* Amazon Web Services (AWS)
* Amazon EKS
* Amazon ECR
* Amazon VPC
* IAM
* Route53
* ACM
* Application Load Balancer

### Infrastructure as Code

* Terraform

### Containerization

* Docker
* Docker Compose

### Container Orchestration

* Kubernetes
* kubectl
* Kind (Local Development)

### CI/CD

* GitHub Actions

### Backend

* Python
* Flask
* Gunicorn

### Database

* PostgreSQL

### Monitoring & Observability

* Prometheus Metrics
* Health Checks
* Structured Logging

### Version Control

* Git
* GitHub

---

# Project Architecture

```bash

                            +--------------------------------------+
                            |          AgileOps Portal             |
                            | Cloud-Native DevOps Project          |
                            +--------------------------------------+

                                        Developer
                                            │
                                            ▼
                                    +-------------------+
                                    | GitHub Repository |
                                    +-------------------+
                                            │
                                            ▼
                                    +-------------------------+
                                    | GitHub Actions Pipeline |
                                    +-------------------------+
                                            │
                                            ├──────────────► Unit Testing
                                            │
                                            ├──────────────► Docker Image Build
                                            │
                                            └──────────────► Push Image to Amazon ECR
                                                                │
                                                                ▼
                                                    +-------------------------+
                                                    | Terraform Infrastructure|
                                                    +-------------------------+
                                                                │
                                                                ▼
                                                        +----------------------+
                                                        | Amazon EKS Cluster   |
                                                        +----------------------+
                                                                │
                                            ┌─────────────────────┼─────────────────────┐
                                            │                     │                     │
                                            ▼                     ▼                     ▼
                                    Deployment             Service              ConfigMap/Secret
                                            │                     │
                                            └──────────────┬──────┘
                                                        ▼
                                                AWS Load Balancer
                                                        │
                                                        ▼
                                                AgileOps Portal Pods
                                                        │
                                                        ▼
                                                PostgreSQL Database
                                                        │
                                                        ▼
                                            Health Checks • Metrics • Logs
                                                        │
                                                        ▼
                                                        End Users
```

# Repository Structure

```text
.
├── infra/                 # Terraform Infrastructure
├── k8s/            # Kubernetes Manifests
├── .github/
│   └── workflows/         # GitHub Actions Pipelines
├── src/                   # AgileOps Portal Application
├── docs/                  # Project Documentation
└── README.md              # Project Overview
```

---

# Features

* Agile Collaboration Portal
* Sprint Retrospectives
* Jira-style Ticket Management
* Team Management
* Authentication & Authorization
* Containerized Application
* Kubernetes Deployment
* Horizontal Scalability
* Health Monitoring
* Metrics Endpoint
* Cloud-Native Deployment
* Infrastructure as Code
* Automated CI/CD Pipeline

---

# Deployment Workflow

```bash
                                        AgileOps Portal
                        Cloud-Native DevOps & Kubernetes Architecture

                                    ┌────────────────────┐
                                    │     Developer      │
                                    └─────────┬──────────┘
                                            │
                                            │ Code Changes
                                            ▼
                                    ┌────────────────────┐
                                    │ GitHub Repository  │
                                    └─────────┬──────────┘
                                            │
                                            │ Push / Pull Request
                                            ▼
                                    ┌───────────────────────────────────────────────┐
                                    │          GitHub Actions CI/CD Pipeline        │
                                    ├───────────────────────────────────────────────┤
                                    │ • Checkout Source Code                        │
                                    │ • Install Dependencies                        │
                                    │ • Run Unit Tests                              │
                                    │ • Build Docker Image                          │
                                    │ • Push Docker Image to Amazon ECR             │
                                    │ • Deploy Kubernetes Manifests                 │
                                    └─────────┬─────────────────────────────────────┘
                                            │
                                            ▼
                                    ┌────────────────────┐
                                    │     Amazon ECR     │
                                    │ Docker Image Store │
                                    └─────────┬──────────┘
                                            │
                                            ▼
                                    ┌──────────────────────────────────────────────┐
                                    │ Terraform Infrastructure Provisioning        │
                                    ├──────────────────────────────────────────────┤
                                    │ • VPC                                        │
                                    │ • Public & Private Subnets                   │
                                    │ • Internet Gateway                           │
                                    │ • Route Tables                               │
                                    │ • Security Groups                            │
                                    │ • IAM Roles                                  │
                                    │ • Amazon EKS                                 │
                                    │ • Amazon RDS                                 │
                                    └─────────┬────────────────────────────────────┘
                                            │
                                            ▼
                ═══════════════════════════════════════════════════════════════════════
                                    Amazon EKS Kubernetes Cluster
                ═══════════════════════════════════════════════════════════════════════

                                Control Plane (Managed by AWS)
                            ┌───────────────────────────────────────┐
                            │ API Server                            │
                            │ Scheduler                             │
                            │ Controller Manager                    │
                            │ etcd                                 │
                            └───────────────────────────────────────┘
                                            │
                                            ▼
                                    Worker Nodes / Node Group
            ┌─────────────────────────────────────────────────────────────────────┐
            │                                                                     │
            │   Deployment                                                        │
            │        │                                                            │
            │        ▼                                                            │
            │   ReplicaSet                                                        │
            │        │                                                            │
            │        ├──────────────┬──────────────┬──────────────┐               │
            │        ▼              ▼              ▼              │               │
            │      Pod-1          Pod-2          Pod-3            │               │
            │        │              │              │              │               │
            │        └──────────────┴──────────────┘              │               │
            │                     │                               │               │
            │                     ▼                               │               │
            │                  Kubernetes Service                │               │
            │                     │                               │               │
            │                     ▼                               │               │
            │            AWS Application Load Balancer           │               │
            │                     │                               │               │
            └─────────────────────┼───────────────────────────────┘
                                        ┼
                                        ▼
                            AgileOps Portal Application
                                        │
                            ┌───────────┼────────────┐
                            │           │            │
                            ▼           ▼            ▼
                    Authentication   Ticket Mgmt   Retrospectives
                            │            │            │
                            └────────────┴────────────┘
                                        │
                                        ▼
                                Amazon RDS PostgreSQL
                                        │
                                        ▼
                                Persistent Application Data

                ═══════════════════════════════════════════════════════════════════════

                                Monitoring & Observability

                                Prometheus Metrics Endpoint
                                        │
                                        ▼
                                    Health Checks
                                        │
                                        ▼
                                Application Logs

                ═══════════════════════════════════════════════════════════════════════

                                    End Users
                                    │
                                    ▼
                                Web Browser / API

```

---

# Local Development

The application can be executed locally using Docker or by running the Flask application directly.

Detailed application-specific setup instructions are available inside the **`src/README.md`**.

---

# Learning Outcomes

This project demonstrates practical experience with:

* Kubernetes
* Amazon EKS
* Docker
* Terraform
* GitHub Actions
* AWS Networking
* Infrastructure Automation
* CI/CD Pipelines
* Kubernetes Networking
* Service Discovery
* Kubernetes Security
* Cloud-Native Application Deployment

---

# Application Documentation

The complete application documentation, including setup instructions, API details, features, and implementation specifics, is available inside:

```text
src/README.md
```

This repository-level README provides the overall project architecture and deployment workflow, while the application-specific documentation is maintained separately for better organization.

---

# License

This project is intended for learning, experimentation, and demonstrating modern DevOps and Kubernetes deployment practices.

