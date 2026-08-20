# Terraform EKS Three-Tier Deployment

## 1. Project Overview

This project is a completely new end-to-end **three-tier Student Portal application** deployed on AWS using **Amazon EKS and Terraform**.

The application is designed to provide a portal where users can access quizzes covering different technical concepts such as:

* Terraform
* Kubernetes
* Docker
* DevOps and related concepts

The application will also support uploading quiz files, which will be processed as part of the application workflow.

The infrastructure will be created using Terraform, while Kubernetes-based services and supporting tools will be managed separately.

The overall goal is to build a production-style AWS deployment with proper infrastructure separation, Kubernetes deployment, CI/CD, monitoring, and GitOps practices.

---

# 2. High-Level Architecture

The project will follow a three-tier application architecture:

```text
                    AWS
                     |
                    VPC
                     |
              ┌──────┴──────┐
              |             |
           Frontend       Backend
              |             |
              └──────┬──────┘
                     |
                  Database
```

The application infrastructure will run on **Amazon EKS**, with the underlying AWS infrastructure created and managed using Terraform.

Additional Kubernetes services such as **ArgoCD, Prometheus, and Grafana** will be deployed after the core infrastructure is ready.

---

# 3. Terraform Version

The project uses:

```text
Terraform: 1.15.1
```

A fixed Terraform version is intentionally used instead of specifying only a major or minor version.

For example, instead of allowing:

```text
Terraform 1.x
```

or:

```text
Terraform 1.15.x
```

the project explicitly uses:

```text
Terraform 1.15.1
```

### Why?

Using a fixed version provides predictable and consistent Terraform behavior across:

* Local development
* GitHub Actions
* CI/CD pipelines
* Infrastructure deployments

If Terraform automatically upgrades to a newer version, there could potentially be compatibility issues with the existing Terraform configuration, providers, modules, or state.

Therefore, the same Terraform version should be used consistently across local development and the GitHub Actions pipeline.

---

# 4. Terraform Version Management with tfenv

The local system initially had:

```text
Terraform 1.12.1
```

To manage multiple Terraform versions, **tfenv (Terraform Version Manager)** is used.

tfenv allows different Terraform versions to be installed and switched when required.

Terraform 1.15.1 was installed using tfenv and selected as the active version.

## Commands

```bash
tfenv install 1.15.1
tfenv use 1.15.1
```
This ensures that the infrastructure is developed and tested against the same Terraform version that will later be used in the CI/CD pipeline.

---

# 5. Project Folder Structure

```text
terraform-eks-three-tier-deployment/
│
├── eks/
│   ├── eks-core-infra/
│   │   ├── variables.tf
│   │   ├── versions.tf
│   │   ├── provider.tf
│   │   ├── output.tf
│   │   ├── iam.tf
│   │   ├── network.tf
│   │   └── eks.tf
│   │
│   └── k8s-services/
│
└── app/
```

### EKS

The `eks` folder contains everything related to the EKS platform.

* **`eks-core-infra/`** → Creates the core AWS infrastructure such as VPC, networking, IAM, and EKS cluster.
* **`k8s-services/`** → Contains Kubernetes/platform services such as ArgoCD, Prometheus, and Grafana, which are deployed after the core infrastructure is ready.

### App

The `app/` folder contains the actual **Student Portal three-tier application**, including the frontend, backend, and application functionality such as technical quizzes and quiz-file uploads.

---



