# EKS Core Infrastructure — Terraform

## Purpose

For the DevOps Dojo project, the EKS core infrastructure is kept in a separate Terraform folder/state so the AWS platform can be created and managed independently from the application infrastructure and Kubernetes deployment. The outcome of this phase is a ready-to-use EKS cluster, VPC, private/public networking, and worker nodes where our application will run.

## What We Created

The core infrastructure mainly consists of the VPC/network configuration and EKS configuration.

### Network — `network.tf`

Using the `terraform-aws-modules/vpc/aws` module, we created:

- VPC: `dojo-vpc`
- CIDR: `10.0.0.0/16`
- 2 Public Subnets
- 2 Private Subnets
- Availability Zones: `us-east-1a`, `us-east-1b`
- Single NAT Gateway
- DNS hostnames/support enabled
- Kubernetes subnet tags for future AWS Load Balancers

The private subnets are used for the EKS worker nodes, while the public subnets provide the public-side networking required by the infrastructure.

### EKS — `eks.tf`

Using `terraform-aws-modules/eks/aws`, we created:

- EKS Cluster: `dojo-eks`
- Kubernetes version: `1.34`
- Public EKS API endpoint
- Cluster creator admin permissions
- EKS Managed Node Group
- Instance type: `m5.xlarge`
- Desired nodes: `2`
- Minimum nodes: `1`
- Maximum nodes: `5`
- AL2023 x86_64 nodes
- Nodes placed in private subnets

Required EKS add-ons were also enabled:

- CoreDNS — Kubernetes DNS/service discovery
- VPC CNI — Pod networking
- kube-proxy — Kubernetes Service networking
- EKS Pod Identity Agent — Pod AWS identity support

## Terraform State

This EKS infrastructure has its own Terraform state. This keeps the EKS/network layer independent from the application infrastructure such as RDS and ECR.

The overall structure is:

    EKS Core Terraform
          ↓
    VPC + Networking
          ↓
    EKS Cluster
          ↓
    Managed Worker Nodes
          ↓
    Ready for Application Deployment

## Deployment Commands

First authenticate locally using AWS SSO:

    aws sso login

Verify the AWS account:

    aws sts get-caller-identity

Initialize Terraform:

    terraform init

Validate the configuration:

    terraform validate

Review the resources:

    terraform plan

Create the infrastructure:

    terraform apply

## Post-Deployment Verification

### 1. Verify EKS Cluster

    aws eks describe-cluster \
      --name dojo-eks \
      --query "cluster.status" \
      --output text

Expected:

    ACTIVE

### 2. Get Node Groups

    aws eks list-nodegroups \
      --cluster-name dojo-eks

### 3. Verify Node Group Status

    aws eks describe-nodegroup \
      --cluster-name dojo-eks \
      --nodegroup-name <NODE_GROUP_NAME> \
      --query "nodegroup.status" \
      --output text

Expected:

    ACTIVE

### 4. Check Node IAM Role

Get the IAM role used by the nodes:

    aws eks describe-nodegroup \
      --cluster-name dojo-eks \
      --nodegroup-name <NODE_GROUP_NAME> \
      --query "nodegroup.nodeRole" \
      --output text

Then check its attached policies:

    aws iam list-attached-role-policies \
      --role-name <NODE_ROLE_NAME>

The important policy we verified was:

    AmazonEC2ContainerRegistryReadOnly

This confirms that the EKS worker nodes have permission to pull private Docker images from ECR.

The node role also contains:

    AmazonEKS_CNI_Policy
    AmazonEKSWorkerNodePolicy

### 5. Configure kubectl

    aws eks update-kubeconfig \
      --region us-east-1 \
      --name dojo-eks

Verify the nodes:

    kubectl get nodes

Verify Kubernetes system Pods:

    kubectl get pods -A

Verify EKS add-ons:

    aws eks list-addons \
      --cluster-name dojo-eks

## Important Verification Result

The EKS managed node group IAM role already has:

    AmazonEC2ContainerRegistryReadOnly

Therefore, we do not need to create another IAM role or ECR pull policy for the worker nodes.

The image flow will be:

    GitHub Actions
          ↓
    Push Image → ECR
          ↑
          │
    EKS Node IAM Role
          ↓
    Pull Image ← ECR
          ↓
    Pod starts

## Phase Outcome

After completing this phase, we have the AWS foundation required for the application:

    VPC
      ↓
    Public + Private Subnets
      ↓
    NAT Gateway
      ↓
    EKS Cluster
      ↓
    Managed Worker Nodes
      ↓
    EKS Add-ons
      ↓
    ECR Pull Permission Verified
      ↓
    Ready for Kubernetes Application Deployment
