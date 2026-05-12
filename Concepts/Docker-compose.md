# Docker Compose Concepts - Interview Notes

# What is Docker Compose?

Docker Compose is a tool used to define and manage multi-container Docker applications using a YAML configuration file.

Instead of manually running multiple `docker run` commands, Compose manages:

* containers
* networks
* volumes
* environment variables
* dependencies

using a single file:

```text id="fg5f7w"
docker-compose.yaml
```

---

# Why Docker Compose?

Without Compose:

```bash id="cp0d5q"
docker run ...
docker run ...
docker network create ...
docker volume create ...
```

Too many manual steps.

Compose automates infrastructure and application startup.

---

# Core Docker Compose Concepts

---

# 1. services

```yaml id="wlw0wa"
services:
```

Defines all application containers.

Each service becomes:

```text id="kh7o1c"
One container
```

Example:

```yaml id="vynfkl"
services:
  app:
  postgres:
```

---

# 2. image

```yaml id="26cfos"
image: postgres:16
```

Pulls image directly from Docker Hub or registry.

Used when prebuilt image already exists.

---

# 3. build

```yaml id="0zy49x"
build:
  context: .
```

Builds custom Docker image using local Dockerfile.

Equivalent:

```bash id="om4o4u"
docker build .
```

---

# 4. ports

```yaml id="y16g6m"
ports:
  - "8081:8000"
```

Maps:

```text id="3l0u9k"
Host Port → Container Port
```

Example:

```text id="p8vfh9"
localhost:8081 → container:8000
```

Used to expose applications outside container.

---

# 5. environment

```yaml id="2c0d97"
environment:
```

Passes environment variables into container.

Common use cases:

* DB credentials
* API keys
* application configs
* runtime settings

Example:

```yaml id="9w55mb"
POSTGRES_USER: postgres
```

---

# 6. volumes

```yaml id="8jlwmm"
volumes:
```

Provides persistent storage.

Important because:

```text id="s0ls5d"
Containers are ephemeral
```

Deleting container deletes internal filesystem.

Volumes preserve data independently.

---

# Types of Volumes

## Named Volume

```yaml id="pru14v"
pgdata:/var/lib/postgresql/data
```

Docker-managed persistent storage.

Most common production usage.

---

## Bind Mount

```yaml id="dldifm"
./app:/app
```

Maps local host directory into container.

Used mostly in development.

---

# 7. networks

```yaml id="kp7l1j"
networks:
```

Allows containers to communicate securely.

Docker provides embedded DNS automatically.

Containers communicate using:

```text id="w5d4kk"
Service names
```

instead of IP addresses.

Example:

```text id="x6ajhj"
app → postgres
```

---

# 8. depends_on

```yaml id="jlwm356"
depends_on:
```

Defines service startup dependency.

Example:

```yaml id="jlwm357"
depends_on:
  - postgres
```

Means:

```text id="’wini358"
Start postgres before app
```

---

# Problem with Basic depends_on

Container may start but application inside may NOT be ready.

This causes:

```text id="’wini359"
Startup race condition
```

---

# Better Production Approach

```yaml id="’wini360"
depends_on:
  postgres:
    condition: service_healthy
```

Waits until service becomes healthy.

---

# 9. healthcheck

```yaml id="’wini361"
healthcheck:
```

Checks if containerized application is actually ready.

Important concept:

```text id="’wini362"
Container running ≠ application ready
```

Example PostgreSQL healthcheck:

```yaml id="’wini363"
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
```

---

# Healthcheck Parameters

## interval

How often to run check.

---

## timeout

Max wait time for response.

---

## retries

How many failures before unhealthy.

---

## start_period

Grace period during startup.

---

# 10. command

```yaml id="’wini364"
command:
```

Overrides Dockerfile CMD during runtime.

Equivalent:

```bash id="’wini365"
docker run image python app.py
```

Used for:

* debugging
* migrations
* startup scripts
* alternate commands

---

# 11. restart Policies

```yaml id="’wini366"
restart:
```

Controls automatic container restart behavior.

---

# Restart Types

## no

Never restart container.

Default behavior.

---

## always

Always restart container.

Common in production.

---

## unless-stopped

Restart unless manually stopped.

Used frequently for long-running services.

---

## on-failure

Restart only if container exits with failure.

Example:

```yaml id="’wini367"
restart: on-failure:3
```

Retry 3 times maximum.

---

# 12. Docker Compose Networks

Compose automatically creates:

```text id="’wini368"
Project-scoped networks
```

Example:

```text id="’wini369"
studentapp_default
```

All services inside same compose file automatically join this network.

---

# 13. Docker Compose Volumes

Compose automatically manages named volumes.

Example:

```text id="’wini370"
studentapp_pgdata
```

Volumes survive:

* container restart
* container deletion
* compose restart

unless removed explicitly.

---

# Important Compose Commands

---

# Start Compose

```bash id="’wini371"
docker compose up
```

---

# Build + Start

```bash id="’wini372"
docker compose up --build
```

Rebuilds images before startup.

---

# Detached Mode

```bash id="’wini373"
docker compose up -d
```

Runs in background.

---

# Stop Compose

```bash id="’wini374"
docker compose down
```

Removes:

* containers
* compose networks

Keeps volumes safe.

---

# Remove Everything Including Volumes

```bash id="’wini375"
docker compose down -v
```

Deletes persistent data too.

---

# View Logs

```bash id="’wini376"
docker compose logs
```

---

# View Running Services

```bash id="’wini377"
docker compose ps
```

---

# Real-World Docker Compose Usage

Used heavily for:

* local development
* QA environments
* integration testing
* developer onboarding
* multi-service applications
* CI/CD validation

before moving to:

* Kubernetes
* ECS
* Docker Swarm

---

# Important Interview One-Liners

## Docker Compose

```text id="’wini378"
Docker Compose is a declarative tool for managing multi-container Docker applications using YAML configuration.
```

---

## Docker Networks

```text id="’wini379"
Docker Compose provides automatic DNS-based service discovery between containers.
```

---

## Docker Volumes

```text id="’wini380"
Volumes provide persistent storage independent from container lifecycle.
```

---

## Health Checks

```text id="’wini381"
Health checks validate application readiness, not just container startup.
```

---

## depends_on

```text id="’wini382"
depends_on controls startup ordering between services but should be combined with health checks for production reliability.
```

---

# Final Learning Outcome

Understood:

* Multi-container architecture
* Docker Compose orchestration
* Service discovery
* Persistent storage
* Health checks
* Restart policies
* Runtime overrides
* Production-style container communication
