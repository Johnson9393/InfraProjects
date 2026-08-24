# Docker Buildx, Docker Optimization & GitHub Actions Cache

This reference explains three important concepts used in the CI/CD pipeline:

```text
GitHub Actions
      ↓
Docker Buildx
      ↓
Docker Build Optimization + Cache
      ↓
ECR
      ↓
EKS
```

---

# 1. Docker Buildx

## What is Buildx?

Docker Buildx is an advanced Docker build tool based on BuildKit.

In our GitHub Actions pipeline, Buildx is used to build Docker images efficiently and provides features such as:

* Build caching
* Parallelized builds
* Multi-platform builds
* Efficient image exporting/pushing

### Simple Use Case

Instead of:

```text
GitHub Actions
      ↓
docker build
      ↓
Docker Image
      ↓
ECR
```

we use:

```text
GitHub Actions
      ↓
Docker Buildx
      ↓
Optimized Build + Cache
      ↓
ECR
```

## Why do we use Buildx?

The main reason for our project is **efficient and cacheable Docker builds**.

If only application code changes, Buildx can reuse previously built Docker layers instead of rebuilding everything.

Example:

```text
Previous Build

Python Base Image      → Cached
Dependencies           → Cached
Application Code       → Build again
```

Instead of:

```text
Python Base Image      → Build again
Dependencies           → Build again
Application Code       → Build again
```

## Advantages

* Faster Docker builds
* Supports build caching
* Reduces unnecessary rebuilding
* Supports multi-platform images
* Can push images directly to ECR
* Works very well with GitHub Actions

---

# 2. Docker Build Optimization

## Why do we optimize Docker builds?

A poorly designed Dockerfile can make every pipeline execution rebuild a large amount of data unnecessarily.

Example:

```text
Docker Image = 1 GB

100 builds
     ↓
100 × unnecessary work
```

This results in:

* Longer pipeline execution
* Higher build resource usage
* More network traffic
* Slower deployments

With EKS, image size also matters because Kubernetes nodes need to pull the image.

For example:

```text
1 GB Image
   ×
100 Image Pulls
   =
100 GB Data Transfer
```

If this traffic goes through a NAT Gateway, it can also increase network/data-processing costs.

---

## How do we optimize Docker builds?

### 1. Use a smaller base image

Instead of using a very large base image, use an appropriate smaller image.

Example:

```dockerfile
FROM python:3.13-slim
```

instead of unnecessarily using a much larger image.

---

### 2. Use Docker layer caching

Docker images are built using layers.

Example:

```text
Docker Image
│
├── Base Image
├── Dependencies
└── Application Code
```

If dependencies haven't changed:

```text
Base Image       → Reuse
Dependencies     → Reuse
Application Code → Rebuild
```

This significantly reduces build time.

---

### 3. Order Dockerfile instructions properly

Avoid:

```dockerfile
COPY . .

RUN pip install -r requirements.txt
```

Because changing any application file can invalidate the dependency layer.

Prefer:

```dockerfile
COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .
```

Now:

```text
requirements.txt unchanged
        ↓
Dependency layer reused
        ↓
Only application code rebuilt
```

---

### 4. Use `.dockerignore`

Don't send unnecessary files into the Docker build context.

Example:

```text
.git
.github
.venv
node_modules
__pycache__
*.log
```

This reduces the amount of data Docker needs to process.

---

## Advantages of Docker Optimization

```text
Optimized Dockerfile
        ↓
Smaller Image
        ↓
Faster Build
        ↓
Faster Image Push
        ↓
Faster Image Pull
        ↓
Faster EKS Deployment
        ↓
Lower Network/Infrastructure Cost
```

---

# 3. GitHub Actions Docker Cache

## What is GitHub Actions Cache?

GitHub Actions can store Docker build layers so that future workflow runs can reuse them.

Without caching:

```text
Build 1 → Build everything
Build 2 → Build everything again
Build 3 → Build everything again
```

With caching:

```text
Build 1
   ↓
Build everything
   ↓
Save Docker layers to cache

Build 2
   ↓
Restore cache
   ↓
Reuse unchanged layers
   ↓
Build only changed layers
```

---

# 4. Why do we cache Docker builds in GitHub Actions?

Suppose your Dockerfile has:

```text
Base Image
Dependencies
Application Code
```

You change only:

```text
Application Code
```

There is no reason to download and rebuild:

```text
Base Image
Dependencies
```

again.

The cache allows GitHub Actions/Buildx to reuse those layers.

The result is:

```text
Without Cache
      ↓
Full Build
      ↓
Slow

With Cache
      ↓
Reuse Existing Layers
      ↓
Build Only Changes
      ↓
Faster
```

---

# 5. How do we configure GitHub Actions Cache?

A common Buildx configuration is:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and Push Docker Image
  uses: docker/build-push-action@v6
  with:
    context: .
    push: true
    tags: <ECR_IMAGE>:<COMMIT_ID>
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

The important configuration is:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

### `cache-to`

```text
Buildx
   ↓
Build Docker Image
   ↓
Store reusable layers
   ↓
GitHub Actions Cache
```

### `cache-from`

On the next build:

```text
GitHub Actions Cache
        ↓
Buildx
        ↓
Restore reusable layers
        ↓
Build only changed layers
```

---

# 6. First Build vs Subsequent Builds

### First build

```text
GitHub Actions
      ↓
Buildx
      ↓
No existing cache
      ↓
Build all required layers
      ↓
Push Image to ECR
      ↓
Save Cache
```

### Next build

```text
GitHub Actions
      ↓
Buildx
      ↓
Restore Cache
      ↓
Reuse unchanged layers
      ↓
Build changed layers
      ↓
Push Image to ECR
```

The exact speed improvement depends on the Dockerfile and which layers changed.

---

# 7. GitHub Actions Cache vs Docker Image

These are two different things.

### Docker Image

Stored in:

```text
ECR
```

Used by:

```text
EKS
```

### Build Cache

Stored using:

```text
GitHub Actions Cache
```

Used by:

```text
Buildx
```

So:

```text
Developer
    ↓
GitHub Actions
    ↓
Buildx
    ↓
GitHub Actions Cache
    ↓
Build Docker Image
    ↓
ECR
    ↓
EKS
```

The cache is **not the image that EKS runs**.

It is only reusable build data that helps Buildx create the next image faster.

---

# 8. About Depot

Depot is another solution that can provide remote Docker build infrastructure and caching.

The concept is similar:

```text
GitHub Actions
      ↓
Remote Build Infrastructure
      ↓
Persistent Build Cache
      ↓
Docker Image
      ↓
ECR
```

The important difference is that Depot provides its own remote build/cache infrastructure, while:

```yaml
cache-from: type=gha
cache-to: type=gha
```

uses GitHub Actions' cache mechanism.

For our initial implementation, GitHub Actions cache with Buildx is sufficient.

Depot can be evaluated later if build speed, scale, concurrency, or persistent caching becomes a significant requirement.

---

# 9. Complete CI/CD Flow

Our intended pipeline is:

```text
Developer Push
      ↓
GitHub Actions
      ↓
Setup Buildx
      ↓
Restore Docker Cache
      ↓
Build Docker Image
      ↓
Reuse Unchanged Layers
      ↓
Build Changed Layers
      ↓
Push Image to ECR
      ↓
EKS Pulls Image
      ↓
Application Deployment
```

---

# 10. Key Points to Remember

### Buildx

> **Buildx provides an efficient Docker build engine with advanced features, especially caching.**

### Docker Optimization

> **Optimize Dockerfiles to reduce image size and avoid rebuilding unnecessary layers.**

### GitHub Actions Cache

> **Store reusable Docker build layers so future GitHub Actions runs can reuse them instead of rebuilding everything.**

### Depot

> **Depot is an alternative remote build and caching solution that can be considered when larger-scale or faster Docker builds are required.**

### Overall Goal

```text
Better Dockerfile
      +
Buildx
      +
Build Cache
      ↓
Faster Builds
      ↓
Smaller Images
      ↓
Faster EKS Deployments
      ↓
Lower Resource & Network Costs
```
