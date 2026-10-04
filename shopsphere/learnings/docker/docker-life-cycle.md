# Docker Architecture & Image Lifecycle

## 1. Core Docker Architecture

```text
Docker CLI
    ↓
Docker Engine (dockerd)
    ↓
    ├── BuildKit → builds Docker images
    │
    └── containerd → manages container lifecycle
                     ↓
                    runc
                     ↓
                Linux Kernel
             ┌───────┴────────┐
        namespaces          cgroups
         isolation       resource limits
             └───────┬────────┘
                     ↓
                 Container
                     ↓
               Application
```

### Components

* **Docker CLI** — commands such as `docker build`, `docker run`, `docker ps`.
* **dockerd** — Docker daemon/engine that receives and manages Docker requests.
* **BuildKit** — modern Docker image builder; handles build stages, caching and efficient builds.
* **containerd** — manages container lifecycle.
* **runc** — creates and starts containers using Linux kernel primitives.
* **Namespaces** — provide process, network, filesystem and other isolation.
* **cgroups** — control CPU, memory and other resource usage.
* **Registry** — stores and distributes images, e.g. Amazon ECR.

---

## 2. Building a Docker Image

Example:

`docker build -t shopsphere-product-service:1.0 .`

Flow:

```text
Docker CLI
    ↓
Docker Engine
    ↓
BuildKit
    ↓
Dockerfile + Build Context
    ↓
.dockerignore filters unnecessary files
    ↓
Dockerfile instructions executed
    ↓
Cache reused where possible
    ↓
Build stages completed
    ↓
Final Docker Image
```

### Build Context

The `.` means the current directory is the build context.

`.dockerignore` prevents unnecessary files from being sent to the builder.

Typical exclusions:

* `.git`
* `.env`
* logs
* IDE files
* tests when not required for the production image
* documentation
* local build artifacts

`Dockerfile` and `README.md` can remain in GitHub; excluding them from `.dockerignore` only controls the Docker build context.

---

## 3. Dockerfile Layers and Cache

Dockerfile instructions create filesystem changes that can participate in image layers and BuildKit caching.

For a Go application:

```text
COPY go.mod go.sum
        ↓
RUN go mod download
        ↓
COPY source code
        ↓
RUN go build
```

This ordering improves caching.

If application source changes but `go.mod` and `go.sum` remain unchanged, dependency-related cache can be reused.

General rule:

**Put infrequently changing instructions before frequently changing instructions.**

---

## 4. Multi-Stage Builds

Production images should separate building from running.

```text
Builder Stage
    ↓
Go compiler + dependencies + source
    ↓
Compile application
    ↓
Application binary
    ↓
Runtime Stage
    ↓
Minimal runtime environment
    ↓
Final production image
```

Build tools and unnecessary source files do not need to be included in the final runtime image.

Benefits:

* Smaller image
* Smaller attack surface
* Fewer unnecessary packages
* Cleaner production runtime

---

## 5. Docker Image

A Docker image is an **immutable, layered package** containing the application, required runtime files/dependencies and metadata needed to create a container.

```text
Docker Image
├── Base/runtime layer
├── Dependency layers
├── Application layers
└── Image metadata
```

Images are normally treated as immutable.

If the application changes:

```text
shopsphere-product-service:1.0
        ↓
new build
        ↓
shopsphere-product-service:1.1
```

Do not modify a running image manually and treat it as a new version.

---

## 6. Image vs Container

```text
Docker Image
      │
      │ docker run
      ▼
Container
```

* **Image** = immutable package/template.
* **Container** = running instance created from an image.

Multiple containers can be created from the same image.

```text
shopsphere-product-service:1.0
        ├── Container 1
        ├── Container 2
        └── Container 3
```

Image layers are read-only. A running container gets a writable container layer on top.

```text
Container
┌─────────────────────────┐
│ Writable container layer│
├─────────────────────────┤
│ Read-only image layer   │
├─────────────────────────┤
│ Read-only image layer   │
└─────────────────────────┘
```

Container-specific filesystem changes disappear when the container is removed unless persistent storage is used.

---

## 7. Running a Container

Example:

`docker run shopsphere-product-service:1.0`

Internal flow:

```text
Docker CLI
    ↓
dockerd
    ↓
containerd
    ↓
runc
    ↓
Linux Kernel
    ↓
Container Process
    ↓
Application
```

### What happens internally?

* `dockerd` receives the request.
* `containerd` manages the container lifecycle.
* `runc` creates and starts the container.
* Linux namespaces provide isolation.
* Linux cgroups provide resource controls.
* The application runs as a process inside the container.

A container is **not a virtual machine**. It is an isolated process/process tree using the host's Linux kernel.

---

## 8. Namespaces vs cgroups

### Namespaces

**Isolation — what the process can see.**

Examples:

* Process namespace
* Network namespace
* Mount namespace
* Hostname/UTS namespace

### cgroups

**Resource control — how much the process can use.**

Examples:

* CPU
* Memory
* Other resource limits

Example:

`docker run --memory=512m --cpus=1 shopsphere-product-service:1.0`

---

## 9. Docker Networking and Ports

If Product Service listens inside the container on port `8001`:

`docker run -p 8001:8001 shopsphere-product-service:1.0`

Meaning:

```text
-p HOST_PORT:CONTAINER_PORT

8001:8001
  │     │
  │     └── container port
  └──────── host port
```

Traffic:

```text
localhost:8001
      ↓
Docker Host
      ↓
Container:8001
      ↓
Product Service
```

`EXPOSE 8001` in a Dockerfile does **not** publish the port. It declares/document the intended container port.

---

## 10. Container-to-Container Communication

Containers communicate through Docker networks.

Do not normally use:

`localhost`

to reach another container.

Instead, use the other service/container's DNS name.

Example:

```text
Product Service
      ↓
postgres:5432
      ↓
PostgreSQL Container
```

Docker's internal DNS resolves the service/container name.

This becomes important when running ShopSphere through Docker Compose.

---

## 11. Production Docker Image Principles

For ShopSphere production images:

* Use multi-stage builds where applicable.
* Use minimal and appropriate runtime images.
* Use `.dockerignore`.
* Optimize layer/cache ordering.
* Do not bake secrets into images.
* Run as a non-root user where possible.
* Keep unnecessary packages out of the runtime image.
* Use deterministic dependency versions.
* Use meaningful image tags.
* Handle application signals correctly.
* Add health checks where appropriate.
* Keep the final image small and security-focused.

---

## 12. Complete Mental Model

```text
                 BUILD
                  │
                  ▼
Dockerfile + Build Context
                  │
                  ▼
              BuildKit
                  │
        ┌─────────┴─────────┐
        │                   │
      Cache             Build Stages
        │                   │
        └─────────┬─────────┘
                  ▼
             Docker Image
                  │
             docker run
                  ▼
               dockerd
                  │
               containerd
                  │
                 runc
                  │
             Linux Kernel
              /         \
       namespaces       cgroups
        isolation      resources
              \         /
               Container
                  │
                  ▼
             Application
                  │
                  ▼
            Docker Network
                  │
                  ▼
          Other Containers
```

## Interview Summary

**Docker image:**
An immutable, layered package containing the application, runtime dependencies/files and metadata required to create a container.

**Docker container:**
A running instance of an image, isolated using Linux kernel mechanisms such as namespaces and controlled using cgroups.

**`docker build`:**
Docker CLI sends the build request to the Docker engine. BuildKit processes the Dockerfile and build context, applies caching and build stages, and produces the final image.

**`docker run`:**
Docker CLI sends the request to the Docker daemon. The daemon delegates lifecycle management to containerd, which uses runc to create the container using Linux kernel isolation and resource-control mechanisms.

**Image vs container:**
Image is the immutable package; container is the runtime instance.

**Namespaces vs cgroups:**
Namespaces provide isolation; cgroups provide resource control.

**BuildKit:**
Modern Docker build engine responsible for efficient image building, caching and multi-stage builds.

**containerd vs runc:**
containerd manages the container lifecycle; runc creates and starts the actual container using Linux kernel primitives.
