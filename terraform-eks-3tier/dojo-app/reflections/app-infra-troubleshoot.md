# App Infrastructure — Terraform

## Overview

This App Infra layer manages the application-side infrastructure after the EKS Core Infra is available.

It includes:

- RDS PostgreSQL
- ECR repositories
- AWS Secrets Manager
- RDS/application secrets
- Kubernetes Namespace
- Kubernetes ConfigMaps
- Kubernetes Secrets
- Kubernetes Services

AWS resources are managed through the AWS Terraform provider, while Kubernetes resources are managed through the Kubernetes Terraform provider through the EKS API.

## 1. EKS Prerequisite

Before applying App Infra, the EKS cluster must already exist and be active.

Check the cluster:

    aws eks describe-cluster \
      --region us-east-1 \
      --name dojo-eks \
      --query "cluster.status"

Expected:

    "ACTIVE"

Configure the local kubeconfig:

    aws eks update-kubeconfig \
      --region us-east-1 \
      --name dojo-eks

Verify the context:

    kubectl config current-context

Expected:

    dojo-eks

Verify worker nodes:

    kubectl get nodes

All worker nodes should show `Ready`.

## 2. Kubernetes Terraform Provider

The Kubernetes provider was initially missing from `versions.tf`.

Add:

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

For the current local setup, authenticate Terraform to EKS through the local kubeconfig:

    provider "kubernetes" {
      config_path    = "~/.kube/config"
      config_context = "dojo-eks"
    }

After changing `versions.tf`, initialize Terraform again:

    terraform init -upgrade

Then validate:

    terraform validate

## 3. First Kubernetes Provider Error

Error:

    Error: Post "http://localhost/api/v1/namespaces":
    dial tcp [::1]:80: connect: connection refused

Cause:

Terraform's Kubernetes provider was not configured to connect to the EKS cluster. It therefore attempted to use the default localhost Kubernetes API endpoint.

Fix:

Configure the Kubernetes provider with the EKS kubeconfig:

    provider "kubernetes" {
      config_path    = "~/.kube/config"
      config_context = "dojo-eks"
    }

Then run:

    terraform init -upgrade
    terraform plan

After the provider was correctly configured, Terraform successfully connected to EKS and created the Kubernetes resources.

## 4. Secrets Manager Deletion Problem

During an earlier destroy/recreate cycle, Terraform attempted to create:

    dojo-dev-rds-secret

AWS returned:

    InvalidRequestException:
    You can't create this secret because a secret with this name
    is already scheduled for deletion.

Check the secret:

    aws secretsmanager describe-secret \
      --secret-id dojo-dev-rds-secret \
      --region us-east-1

If the output contains `DeletedDate`, the secret is scheduled for deletion.

Restore it when necessary:

    aws secretsmanager restore-secret \
      --secret-id dojo-dev-rds-secret \
      --region us-east-1

## 5. Terraform State and Existing Secret

After restoring the secret, Terraform still tried to create it because the secret existed in AWS but was not present in the current Terraform state.

Check:

    terraform state list | grep aws_secretsmanager_secret

If the resource is missing from state, import the existing AWS secret:

    terraform import \
      aws_secretsmanager_secret.rds_secret \
      arn:aws:secretsmanager:us-east-1:023192525105:secret:dojo-dev-rds-secret-jeXgs3

Then verify with:

    terraform plan

The secret itself should no longer appear as a new resource.

## 6. Immediate Secret Deletion for the Lab

Because this is a learning environment where infrastructure is repeatedly created and destroyed, the Secrets Manager resource uses:

    recovery_window_in_days = 0

Example:

    resource "aws_secretsmanager_secret" "rds_secret" {
      name                    = "dojo-dev-rds-secret"
      recovery_window_in_days = 0
    }

This allows the secret to be permanently deleted immediately during `terraform destroy`, so the same secret name can be recreated during the next lab session.

Do not use `prevent_destroy = true` here because the objective is to destroy the lab infrastructure after practice and avoid unnecessary AWS costs.

## 7. Terraform Plan and Apply

After making provider or infrastructure changes:

    terraform init -upgrade

Then:

    terraform validate

Then:

    terraform plan

Review the plan before applying:

    terraform apply

For an automatic approval:

    terraform apply -auto-approve

## 8. Kubernetes Resources Created by App Infra

The Terraform Kubernetes provider creates these objects inside the EKS cluster:

    Namespace
    ConfigMaps
    Secret
    Services

They are Kubernetes resources, not separate AWS resources.

The flow is:

    Terraform
        ↓
    Kubernetes Provider
        ↓
    EKS Kubernetes API
        ↓
    Kubernetes Namespace / ConfigMap / Secret / Service

## 9. Namespace

The project namespace is created using:

    resource "kubernetes_namespace" "dojo" {
      metadata {
        name = var.project
      }
    }

Current namespace:

    dojo

Verify:

    kubectl get namespaces

## 10. ConfigMaps

Backend configuration:

    kubectl get configmap backend-config -n dojo

Frontend configuration:

    kubectl get configmap frontend-config -n dojo

ConfigMaps contain non-sensitive application configuration such as database host, database port, database name, allowed origins, backend URL, application name, and application version.

## 11. Kubernetes Secret

Backend secret:

    kubectl get secret backend-secret -n dojo

The Secret contains sensitive values such as database credentials and the application's secret key.

Verify:

    kubectl get secrets -n dojo

The expected type is:

    Opaque

## 12. Kubernetes Services

Verify:

    kubectl get services -n dojo

Current design:

    backend-service
      Type: ClusterIP
      Port: 8080
      TargetPort: 8000

    frontend-service
      Type: ClusterIP
      Port: 80
      TargetPort: 80

The backend application listens on port `8000`, while the Kubernetes backend Service exposes port `8080` internally and forwards traffic to container port `8000`.

The frontend application listens on port `80`, so its Service exposes port `80` and forwards to port `80`.

Both Services use `ClusterIP` because they are internal services. External traffic will later enter through the AWS Load Balancer Controller and Ingress.

## 13. Final Verification

Verify the complete Kubernetes foundation:

    kubectl get namespace,configmap,secret,service -n dojo

Expected application resources:

    namespace/dojo

    configmap/backend-config
    configmap/frontend-config

    secret/backend-secret

    service/backend-service
    service/frontend-service

Verify worker nodes:

    kubectl get nodes

Verify Terraform state:

    terraform plan

After everything is applied successfully, the expected result is:

    No changes.

## 14. Troubleshooting Sequence

When rebuilding the lab from scratch, follow this order:

    1. Verify EKS is ACTIVE.
    2. Configure kubeconfig.
    3. Verify kubectl can access EKS.
    4. Add/configure the Kubernetes Terraform provider.
    5. Run terraform init -upgrade.
    6. Run terraform validate.
    7. Run terraform plan.
    8. Fix any AWS resource/state conflicts.
    9. Run terraform apply.
    10. Verify Kubernetes resources with kubectl.

## 15. Current App Infra State

At the end of this phase:

    EKS Core Infra
        ↓
    RDS + ECR + Secrets Manager
        ↓
    Kubernetes Namespace
        ↓
    ConfigMaps + Kubernetes Secret
        ↓
    Backend + Frontend Services
        ↓
    Ready for application Deployments

Next phase:

    GitHub Actions
        ↓
    Build Backend Image
    Build Frontend Image
        ↓
    Push Images to ECR
        ↓
    Get ECR Image URI + Tag
        ↓
    Update backend.yaml
    Update frontend.yaml
        ↓
    Deploy Backend + Frontend