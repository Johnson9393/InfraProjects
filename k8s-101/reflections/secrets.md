# Kubernetes Secrets - Complete Notes

## What are Kubernetes Secrets?

A **Secret** is a Kubernetes object used to securely store and manage sensitive information such as passwords, API keys, tokens, certificates, SSH keys, and Docker registry credentials.

Instead of hardcoding sensitive values inside a Deployment YAML, Secrets allow Kubernetes to inject them into Pods securely.

---

# Why use Secrets?

Without Secrets:

```yaml
env:
- name: DB_LINK
  value: "postgresql://pgadmin:password@db:5432/mydb"
```

Problems:

- Password is visible in Git.
- Anyone can read the Deployment YAML.
- Difficult to rotate credentials.

Using Secrets:

```yaml
env:
- name: DB_LINK
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: DB_LINK
```

The Deployment contains only a reference to the Secret.

---

# Kubernetes Secret Types

Kubernetes supports multiple Secret types depending on the use case.

---

## 1. Opaque (Most Common)

```yaml
type: Opaque
```

### Purpose

Stores arbitrary key-value pairs.

### Use Cases

- Database Password
- Database URL
- API Keys
- JWT Secret
- OAuth Client Secret
- Application Configuration

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  DB_LINK: <Base64 Encoded Value>
```

This is the most commonly used Secret type in Kubernetes.

---

## 2. kubernetes.io/dockerconfigjson

### Purpose

Stores Docker Registry credentials.

Used for pulling images from private registries like:

- Amazon ECR
- Docker Hub Private Repositories
- Azure ACR
- Google Artifact Registry

Example:

```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=<registry> \
  --docker-username=AWS \
  --docker-password=<password>
```

Deployment:

```yaml
spec:
  imagePullSecrets:
  - name: ecr-secret
```

This is exactly what we used for pulling images from Amazon ECR.

---

## 3. kubernetes.io/tls

### Purpose

Stores TLS/SSL certificates.

Contains:

- Certificate (.crt)
- Private Key (.key)

Use Cases

- HTTPS
- NGINX Ingress
- API Gateway
- Secure Web Applications

Example:

```yaml
type: kubernetes.io/tls
```

Usually used by Ingress Controllers.

---

## 4. kubernetes.io/basic-auth

### Purpose

Stores username and password.

Keys:

```
username
password
```

Use Cases

- Basic Authentication
- Legacy Applications
- Internal APIs

---

## 5. kubernetes.io/ssh-auth

### Purpose

Stores SSH Private Keys.

Use Cases

- Git Access
- SSH Authentication
- CI/CD Pipelines

Contains

```
ssh-privatekey
```

---

## 6. kubernetes.io/service-account-token

### Purpose

Automatically created by Kubernetes.

Contains a token used by Pods to communicate with the Kubernetes API Server.

Example

```
Bearer Token
```

Use Cases

- Kubernetes API Access
- Controllers
- Operators

Usually Kubernetes manages this Secret automatically.

---

## 7. bootstrap.kubernetes.io/token

### Purpose

Used while joining worker nodes into a Kubernetes cluster using kubeadm.

Use Cases

```
kubeadm join
```

Mostly used during Kubernetes cluster setup.

---

# Secret Type Summary

| Secret Type | Primary Purpose | Real-world Use Case |
|-------------|-----------------|---------------------|
| Opaque | Generic secrets | Database password, API keys, DB URL |
| kubernetes.io/dockerconfigjson | Docker Registry Credentials | Pull images from ECR, Docker Hub, ACR |
| kubernetes.io/tls | TLS Certificates | HTTPS, Ingress |
| kubernetes.io/basic-auth | Username & Password | Legacy authentication |
| kubernetes.io/ssh-auth | SSH Keys | Git, SSH |
| kubernetes.io/service-account-token | Kubernetes API Authentication | Pods talking to API Server |
| bootstrap.kubernetes.io/token | Cluster Bootstrap | kubeadm join |

---

# How Secrets are Used

```
Application
      │
      ▼
Deployment
      │
      ▼
Secret Reference
      │
      ▼
Kubernetes Secret
      │
      ▼
Kubelet
      │
      ▼
Pod Environment Variable
      │
      ▼
Application Receives Plain Text
```

---

# Important Notes

- Secrets are **Base64 encoded**, not encrypted by default.
- Kubernetes automatically decodes Secret values before injecting them into Pods.
- Never hardcode passwords inside Deployment YAML.
- Store Secrets separately from Deployments.
- In production, enable **Encryption at Rest** in etcd and use external secret managers such as AWS Secrets Manager, HashiCorp Vault, or External Secrets Operator for stronger security.

---

# Best Practices

- Store sensitive information in Kubernetes Secrets.
- Use `Opaque` for application secrets like database URLs and API keys.
- Use `dockerconfigjson` for private container registries.
- Use `tls` for certificates.
- Use `imagePullSecrets` only for authenticating image pulls.
- Keep Secret manifests separate from Deployment manifests.
- Avoid committing real Secret values to Git repositories.
- Prefer external secret management solutions in production environments.

---

# What We Implemented

✅ Opaque Secret (`db-secret`) → Stored the PostgreSQL connection string.

✅ Docker Registry Secret (`ecr-secret`) → Authenticated Kubernetes to pull a private image from Amazon ECR using `imagePullSecrets`.

This closely matches a production-style Kubernetes deployment where application credentials and container registry credentials are managed separately.