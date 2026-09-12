# DevOps Dojo — AWS 3-Tier Application

## What is this application?

DevOps Dojo is a **3-tier Student Portal application** running on AWS. It consists of:

- **Frontend** — Web UI
- **Backend** — Application/API layer
- **PostgreSQL Database** — Persistent data layer

The project demonstrates how a production-style application can be **provisioned, containerized, deployed, and continuously delivered using AWS, Kubernetes, Terraform, GitHub Actions, and Argo CD.**

---

## What are we achieving?

The main goal of this project is to build a complete **AWS DevOps / DevSecOps deployment platform** from infrastructure creation to application delivery.

We are achieving:

- Automated AWS infrastructure provisioning using **Terraform**
- Kubernetes application deployment using **Amazon EKS**
- Container image build and storage using **Docker + Amazon ECR**
- CI/CD using **GitHub Actions**
- GitOps-based deployment using **Argo CD**
- HTTPS access using **AWS ALB + ACM + Route 53**
- PostgreSQL database using **Amazon RDS**
- Secure AWS authentication from GitHub using **OIDC**
- Separation of infrastructure, application infrastructure, and application deployment

### Final deployment flow

    Developer
       |
       | git push
       v
    GitHub
       |
       +----------------------+
       |                      |
       v                      v
    GitHub Actions        GitHub Actions
    Build Pipeline        Infrastructure Pipelines
       |                      |
       v                      +--> AWS / EKS Infrastructure
      ECR                     |
       |                      +--> Application Infrastructure
       |                            |
       |                            v
       |                         EKS / RDS / ECR
       |
       v
    Kubernetes Manifest
    image tag updated
       |
       v
    Git commit
       |
       v
    Argo CD
       |
       v
    EKS
       |
       v
    Frontend + Backend
       |
       v
    RDS PostgreSQL

---

## Technology Stack

**Cloud:** AWS  
**Infrastructure as Code:** Terraform  
**Containerization:** Docker  
**Kubernetes:** Amazon EKS  
**Container Registry:** Amazon ECR  
**CI/CD:** GitHub Actions  
**GitOps:** Argo CD  
**Load Balancer:** AWS Application Load Balancer  
**DNS:** Route 53  
**TLS:** AWS ACM  
**Database:** Amazon RDS PostgreSQL  
**Authentication:** GitHub OIDC + AWS IAM

---

# Project Structure

    Dojo-eks-3tier/
    ├── EKS/
    │   ├── eks-core-infra/
    │   └── k8s-services/
    │
    ├── dojo-app/
    │   ├── infra/
    │   ├── k8s-services/
    │   └── src/
    │
    └── github-aws-oidc/

---

# Deployment Pipelines

There are **three main deployment pipelines**.

## 1. EKS Core Infrastructure Pipeline

Creates the Kubernetes platform:

    GitHub Actions
          |
          v
      Terraform
          |
          v
      AWS VPC
          |
          v
        EKS
          |
          v
    Managed Node Groups

This provides the base EKS environment.

---

## 2. Application Infrastructure Pipeline

Creates the infrastructure required by the application:

    Terraform
       |
       +--> ECR repositories
       +--> RDS PostgreSQL
       +--> Secrets Manager
       +--> Kubernetes namespace
       +--> Kubernetes Services
       +--> ConfigMaps / Secrets
       +--> ALB Ingress
       +--> ACM
       +--> Route 53

---

## 3. Application CI/CD + Argo CD Pipeline

When application source code changes:

    Developer
       |
       v
    GitHub Push
       |
       v
    GitHub Actions
       |
       +--> Build Frontend Docker image
       |
       +--> Build Backend Docker image
       |
       v
      ECR
       |
       v
    Update Kubernetes
    image tags
       |
       v
    Git commit
       |
       v
    Argo CD
       |
       v
      EKS
       |
       v
    Application deployed

---

# Installation / Deployment Steps

## Step 1 — Bootstrap GitHub OIDC

Create the AWS IAM OIDC provider and GitHub Actions IAM role.

This allows GitHub Actions to authenticate with AWS **without storing AWS access keys in GitHub.**

---

## Step 2 — Deploy EKS Core Infrastructure

Go to:

    EKS/eks-core-infra

Run:

    terraform init
    terraform plan
    terraform apply

This creates the VPC, networking, EKS cluster, and managed node group.

---

## Step 3 — Configure kubectl

    aws eks update-kubeconfig --region us-east-1 --name dojo-eks

Verify:

    kubectl get nodes

---

## Step 4 — Deploy EKS Supporting Services

Go to:

    EKS/k8s-services

Run:

    terraform init
    terraform plan
    terraform apply

This installs services such as:

- AWS Load Balancer Controller
- Argo CD
- Argo CD Ingress

---

## Step 5 — Deploy Application Infrastructure

Go to:

    dojo-app/infra

Run:

    terraform init
    terraform plan
    terraform apply

This creates the application-side AWS and Kubernetes resources including RDS, ECR, Secrets, Services, Ingress, ACM, and Route 53.

---

## Step 6 — Build and Push Application Images

Push application code to GitHub.

GitHub Actions automatically:

    Build Frontend
          |
          v
    Push Frontend → ECR

    Build Backend
          |
          v
    Push Backend → ECR

Images are tagged using the GitHub commit SHA.

---

## Step 7 — Update Kubernetes Manifests

The deployment pipeline updates:

    dojo-app/k8s-services/frontend.yaml
    dojo-app/k8s-services/backend.yaml

with the newly created ECR image tags and commits the changes back to Git.

---

## Step 8 — Argo CD Deploys the Application

Argo CD watches the Git repository.

When the Kubernetes manifests change:

    Git
     |
     v
    Argo CD
     |
     v
    EKS
     |
     +--> Frontend
     |
     +--> Backend
     |
     +--> Database connection

The application is therefore deployed using a **GitOps workflow**.

---

# Final Architecture

    Internet
       |
       v
    Route 53
       |
       v
    AWS ALB
       |
       v
    EKS
       |
       +----------------+
       |                |
       v                v
    Frontend          Backend
                         |
                         v
                    RDS PostgreSQL

    GitHub
       |
       +--> GitHub Actions
       |       |
       |       v
       |      ECR
       |
       +--> Kubernetes Manifests
                |
                v
             Argo CD
                |
                v
               EKS

---

## Result

The completed project demonstrates an end-to-end **Infrastructure → CI → Container Registry → GitOps → Kubernetes → Application → Database** workflow on AWS.