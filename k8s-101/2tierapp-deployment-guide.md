# Kubernetes Deployment Guide - AgileOps Portal

## Overview

This document describes the complete deployment process followed to deploy the **AgileOps Portal** application on a local Kubernetes cluster using **Kind**.

The deployment includes:

- Creating a local Kubernetes cluster using Kind
- Creating a PostgreSQL RDS instance on AWS
- Building and pushing Docker images to Amazon ECR
- Creating Kubernetes Secrets
- Deploying the application
- Exposing the application using a Kubernetes Service
- Accessing the application locally using Port Forwarding

---

# Prerequisites

- Docker Desktop
- kubectl
- Kind
- AWS CLI
- AWS Account
- Amazon ECR Repository
- Amazon RDS PostgreSQL

---

# Step 1 - Create Kind Cluster

Create a Kind configuration.

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
- role: control-plane
- role: worker
- role: worker
```

Create the cluster.

```bash
kind create cluster --config kind-config.yaml
```

Verify cluster.

```bash
kubectl cluster-info

kubectl get nodes

kubectl get pods -A
```

---

# Step 2 - Build Docker Image

```bash
docker build -t file-scanner:1.0 .
```

Verify

```bash
docker images
```

---

# Step 3 - Push Image to Amazon ECR

Authenticate Docker.

```bash
aws ecr get-login-password --region us-east-1 | docker login \
--username AWS \
--password-stdin <repo_uri>>
```

Tag Image.

```bash
docker tag file-scanner:1.0 \
<repo_uri>>/file-scanner:1.0
```

Push Image.

```bash
docker push \
<repo_uri>>/file-scanner:1.0
```

---

# Step 4 - Create PostgreSQL RDS

Create:

- VPC
- Internet Gateway
- Public Subnets
- Route Table
- Security Group
- DB Subnet Group
- PostgreSQL RDS

Wait until RDS becomes available.

Get Endpoint.

```bash
aws rds describe-db-instances \
--db-instance-identifier tiny-pg \
--query "DBInstances[0].Endpoint.Address" \
--output text
```

---

# Step 5 - Create Docker Registry Secret

Create ECR Secret.

```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=<repo_uri>> \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1)
```

Verify

```bash
kubectl get secrets
```

---

# Step 6 - Create Database Secret

Encode DB Connection.

```bash
echo -n "postgresql://pgadmin:<PASSWORD>@<RDS-ENDPOINT>:5432/mydb" | base64
```

Create Secret.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret

type: Opaque

data:
  DB_LINK: <BASE64_STRING>
```

Apply.

```bash
kubectl apply -f secret.yaml
```

Verify.

```bash
kubectl get secrets
```

---

# Step 7 - Create Deployment

Deployment includes:

- 2 Replicas
- Amazon ECR Image
- imagePullSecrets
- DB Secret Injection

Deploy.

```bash
kubectl apply -f deployment.yaml
```

Verify.

```bash
kubectl get deployments

kubectl get pods

kubectl describe pod <pod-name>
```

---

# Step 8 - Create Service

Create ClusterIP Service.

```bash
kubectl apply -f deployment.yaml
```

Verify.

```bash
kubectl get svc
```

---

# Step 9 - Debugging

Describe Pod.

```bash
kubectl describe pod <pod-name>
```

Container Logs.

```bash
kubectl logs <pod-name>

kubectl logs <pod-name> --previous
```

Events.

```bash
kubectl get events
```

---

# Step 10 - Port Forward

Forward Service.

```bash
kubectl port-forward svc/agileops-portal-service 8000:8000
```

Open Browser.

```
http://localhost:8000
```

---

# Useful Kubernetes Commands

Current Context

```bash
kubectl config current-context
```

View Nodes

```bash
kubectl get nodes
```

View Pods

```bash
kubectl get pods
```

View Services

```bash
kubectl get svc
```

View Deployments

```bash
kubectl get deployments
```

View Secrets

```bash
kubectl get secrets
```

Describe Deployment

```bash
kubectl describe deployment agileops-portal
```

Describe Service

```bash
kubectl describe svc agileops-portal-service
```

Delete Deployment

```bash
kubectl delete deployment agileops-portal
```

Delete Service

```bash
kubectl delete svc agileops-portal-service
```

Delete Secret

```bash
kubectl delete secret db-secret

kubectl delete secret ecr-secret
```

---

# Project Flow

```
Developer
    │
    ▼
Docker Build
    │
    ▼
Amazon ECR
    │
    ▼
Kind Kubernetes Cluster
    │
    ▼
Deployment
    │
    ▼
ReplicaSet
    │
    ▼
Pods
    │
    ├───────────────┐
    ▼               ▼
ECR Secret      DB Secret
    │               │
    ▼               ▼
Image Pull     PostgreSQL RDS
    │               │
    └──────┬────────┘
           ▼
     Application Running
           │
           ▼
ClusterIP Service
           │
           ▼
Port Forward
           │
           ▼
http://localhost:8000
```

---

# Outcome

Successfully deployed the **AgileOps Portal** application on a local Kubernetes cluster using **Kind**, pulled a private container image from **Amazon ECR** using `imagePullSecrets`, securely injected the PostgreSQL connection string through a Kubernetes `Opaque` Secret, connected the application to an **Amazon RDS PostgreSQL** database, exposed it internally using a **ClusterIP Service**, and accessed it locally via **kubectl port-forward**.