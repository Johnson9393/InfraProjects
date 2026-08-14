# Kubernetes Image Pull Policy

## What is imagePullPolicy?

`imagePullPolicy` tells Kubernetes **when the kubelet should pull a container image** from the container registry before starting a Pod.

It is configured inside the container specification.

Example:

```yaml
containers:
- name: agileops-portal
  image: 023192525105.dkr.ecr.us-east-1.amazonaws.com/file-scanner:1.0
  imagePullPolicy: IfNotPresent
```

---

# Types of imagePullPolicy

## 1. Always

```yaml
imagePullPolicy: Always
```

### What it does

Every time a Pod starts, Kubernetes always checks the container registry for the latest image.

If the image exists locally, Kubernetes still contacts the registry first.

### Best Use Cases

- Development
- CI/CD Pipelines
- Frequently changing images
- Using the `latest` tag

### Advantages

- Always pulls the latest image.
- Ensures Pods use the newest version.

### Disadvantages

- Slower Pod startup.
- Requires registry connectivity.

---

## 2. IfNotPresent (Most Common)

```yaml
imagePullPolicy: IfNotPresent
```

### What it does

Kubernetes first checks whether the image already exists on the node.

- If present → Uses the local image.
- If not present → Pulls the image from the registry.

### Best Use Cases

- Production deployments
- Versioned images (e.g., `1.0`, `2.1`)
- Stable releases

### Advantages

- Faster Pod startup.
- Reduces registry traffic.
- Saves bandwidth.

### Disadvantages

- If you overwrite an image with the same tag, Kubernetes continues using the cached local image until it is removed or the tag changes.

---

## 3. Never

```yaml
imagePullPolicy: Never
```

### What it does

Kubernetes never contacts the container registry.

The image **must already exist** on the Kubernetes node.

If the image is missing, the Pod fails with:

```
ErrImageNeverPull
```

### Best Use Cases

- Local development
- Kind
- Minikube
- Air-gapped environments
- Testing locally built images

### Advantages

- Fastest startup.
- No registry access required.

### Disadvantages

- Fails if the image is not already present on the node.

---

# Default Behavior

| Image Tag | Default imagePullPolicy |
|------------|-------------------------|
| `latest` | `Always` |
| Any version tag (`1.0`, `2.0`, etc.) | `IfNotPresent` |

Examples:

```yaml
image: nginx:latest
```

Default:

```yaml
imagePullPolicy: Always
```

---

```yaml
image: file-scanner:1.0
```

Default:

```yaml
imagePullPolicy: IfNotPresent
```

---

# Which one should I use?

| Environment | Recommended Policy |
|-------------|--------------------|
| Local Development | Never |
| Kind / Minikube (local images) | Never |
| Development with ECR/Docker Hub | Always |
| Production | IfNotPresent |
| CI/CD | Always |

---

# What We Used

For our deployment:

- Image stored in **Amazon ECR**
- Versioned image (`file-scanner:1.0`)
- Authentication using `imagePullSecrets`

The recommended policy is:

```yaml
imagePullPolicy: IfNotPresent
```

Reason:

- Uses the cached image if already available on the node.
- Pulls the image only if it is not present.
- Faster and more efficient for versioned production images.