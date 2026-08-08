# Kubernetes Deployment Troubleshooting Guide

## Overview

This document summarizes the issues encountered while deploying the **AgileOps Portal** application on Kubernetes, along with their root causes and resolutions. It serves as a quick troubleshooting guide for future reference.

---

# 1. Deployment Validation Failed

## Error

```
metadata.name: Invalid value
```

Example:

```
agileOps-portal
```

## Cause

Kubernetes resource names must follow the RFC 1123 naming convention.

Rules:

- Lowercase only
- Numbers allowed
- Hyphens (-) allowed
- Cannot contain uppercase characters

## Fix

Changed

```yaml
agileOps-portal
```

to

```yaml
agileops-portal
```

This change was made consistently in:

- Deployment Name
- Container Name
- Labels
- Selectors
- Service Name

---

# 2. ImagePullBackOff

## Error

```
Failed to pull image

no basic auth credentials
```

## Cause

The Docker image was stored in a private Amazon ECR repository.

Kind worker nodes could not authenticate with Amazon ECR.

Without authentication, kubelet cannot pull private images.

---

## Fix

Created an Image Pull Secret.

```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=023192525105.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1)
```

Deployment updated.

```yaml
spec:
  imagePullSecrets:
    - name: ecr-secret
```

Now kubelet successfully authenticates with Amazon ECR before pulling the image.

---

# Where does the Image Pull Secret come from?

When this command is executed:

```bash
aws ecr get-login-password
```

AWS CLI requests a temporary authentication token from Amazon ECR.

That token is **not read from Docker's `config.json`**. Instead:

1. AWS CLI uses your configured AWS credentials (from `~/.aws/credentials`, AWS SSO, or another configured credential source) to call the ECR API.
2. Amazon ECR returns a temporary registry login password (authorization token).
3. `kubectl create secret docker-registry` stores that token inside a Kubernetes Secret (`ecr-secret`).
4. During image pull, the **kubelet** reads the `imagePullSecrets` reference from the Pod spec and passes the credentials to the **container runtime (containerd)**.
5. **containerd** authenticates with Amazon ECR and downloads the image.

> Note: `~/.docker/config.json` stores Docker client login credentials used by the **Docker CLI**. Kubernetes does **not** automatically read that file. Instead, Kubernetes uses the credentials stored in the `ecr-secret` Secret.

Flow:

```
AWS Credentials
       │
       ▼
aws ecr get-login-password
       │
       ▼
Temporary ECR Token
       │
       ▼
Kubernetes Secret (ecr-secret)
       │
       ▼
Kubelet
       │
       ▼
containerd
       │
       ▼
Amazon ECR
       │
       ▼
Docker Image Pulled
```

---

# 3. CrashLoopBackOff

## Error

```
Back-off restarting failed container
```

## Cause

The application started successfully but crashed immediately.

The database connection string was provided as a Base64 string directly inside the Deployment.

Example:

```yaml
env:
- name: DB_LINK
  value: cG9zdG...
```

The application received the Base64 string instead of the actual PostgreSQL connection URL.

---

## Fix

Created a Kubernetes Secret.

```yaml
apiVersion: v1
kind: Secret

type: Opaque

data:
  DB_LINK: <Base64 Encoded Value>
```

Deployment updated.

```yaml
env:
- name: DB_LINK
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: DB_LINK
```

Kubernetes automatically decoded the Secret before injecting it into the container.

The application then received the correct PostgreSQL connection string.

---

# 4. Secret Creation Failed

## Error

```
error: no objects passed to apply
```

## Cause

The Secret YAML file was either:

- Empty
- Not saved
- Invalid YAML

## Fix

Verified the YAML.

```bash
cat secret.yaml
```

Applied again.

```bash
kubectl apply -f secret.yaml
```

---

# 5. Freelens Cluster Disconnected

## Symptom

Freelens showed:

```
Disconnected
```

Although kubectl commands worked.

---

## Cause

Kind cluster had been recreated.

Freelens was still using stale cluster information.

---

## Fix

Removed the cluster from Freelens.

Re-imported:

```
~/.kube/config
```

Freelens connected successfully.

Verification:

```bash
kubectl cluster-info

kubectl config current-context
```

---

# 6. RDS Creation Failed

## Error

```
InvalidSubnet
```

## Cause

Default VPC had no default subnets.

---

## Fix

Created a new VPC with:

- Internet Gateway
- Public Subnets
- Route Table
- Security Group
- DB Subnet Group

Created PostgreSQL RDS successfully.

---

# 7. Public RDS Creation Failed

## Error

```
Cannot create a publicly accessible DB instance.

No Internet Gateway attached.
```

## Cause

The VPC had no Internet Gateway.

---

## Fix

Created and attached:

- Internet Gateway
- Route Table
- Default Route (0.0.0.0/0)

RDS creation succeeded.

---

# 8. DB Subnet Group Not Found

## Error

```
DBSubnetGroupNotFound
```

## Cause

RDS requires a DB Subnet Group before creating the database.

---

## Fix

Created a DB Subnet Group.

```bash
aws rds create-db-subnet-group ...
```

RDS creation succeeded.

---

# Debugging Commands

Pods

```bash
kubectl get pods
```

Describe Pod

```bash
kubectl describe pod <pod-name>
```

Logs

```bash
kubectl logs <pod-name>

kubectl logs <pod-name> --previous
```

Deployments

```bash
kubectl get deployments
```

Services

```bash
kubectl get svc
```

Secrets

```bash
kubectl get secrets
```

Events

```bash
kubectl get events
```

Current Context

```bash
kubectl config current-context
```

Cluster Information

```bash
kubectl cluster-info
```

---

# Key Learnings

- Kubernetes resource names must be lowercase.
- Private Amazon ECR images require an `imagePullSecret`.
- Kubernetes Secrets automatically decode Base64 values before injecting them into containers.
- Never place Base64 values directly inside `env.value`.
- A Kubernetes Secret stores registry credentials separately from your local Docker configuration.
- `kubelet` uses `imagePullSecrets` to authenticate the container runtime (`containerd`) with the image registry.
- `CrashLoopBackOff` indicates that the application started but crashed.
- `ImagePullBackOff` indicates that Kubernetes could not download the container image.
- `kubectl describe pod` and `kubectl logs` are the primary commands for diagnosing deployment issues.