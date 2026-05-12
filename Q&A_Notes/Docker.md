# Docker Exercises - Questions & Answers Notes

# Exercise 1 — Why Volumes Exist

## Why did the file disappear when you created a new container?

Containers are ephemeral.
Data written inside container filesystem exists only for that container lifecycle.

When the container was deleted:

```text id="jlwm383"
Container filesystem was also deleted.
```

New container starts with fresh filesystem from image layer.

---

## In production, what kind of data would you lose if you relied only on container storage?

You may lose:

* database data
* logs
* uploaded files
* session data
* application state

That is why persistent storage like Docker volumes, EBS, or EFS is required.

---

# Exercise 2 — Host Path Mount

## When would you use a read-only mount in production?

Used for:

* nginx config files
* SSL certificates
* static configs
* secrets
* application config files

Reason:

```text id="’wini384"
Container should read config but must NOT modify it.
```

---

## Difference between normal mount and read-only mount?

```bash id="’wini385"
-v ~/data:/data
```

Container can:

* read
* write
* modify

---

```bash id="’wini386"
-v ~/data:/data:ro
```

Container can:

* only read

Write operations fail.

---

# Exercise 3 — Shared Data Between Containers

## What problem occurs if two containers write same file simultaneously?

Possible issues:

* file corruption
* inconsistent data
* race conditions
* overwrite conflicts

Applications need locking or distributed coordination.

---

## On AWS, EBS or EFS for shared storage across containers?

Use:

```text id="’wini387"
EFS
```

because EFS supports:

* multi-instance access
* shared filesystem
* concurrent mounts

EBS usually attaches to one instance only.

---

# Exercise 4 — Named Volumes

## Advantage of `--mount` over `-v`?

`--mount` is:

* more readable
* explicit
* easier to understand
* production preferred

Example:

```bash id="’wini388"
--mount type=volume,source=pgdata,target=/data
```

better explains source and target clearly.

---

## When use `type=bind` instead of `type=volume`?

Use bind mounts when:

* local development
* mounting source code
* accessing local files
* syncing files live

Use volumes for:

* databases
* persistent application storage

---

## Who manages storage path in named volumes?

Docker Engine manages storage path automatically.

User only manages volume name.

---

# Exercise 5 — Dockerfile Basics

## Why copy requirements.txt separately before copying source code?

For Docker layer caching.

If only app code changes:

```text id="’wini389"
pip install layer remains cached
```

and rebuild becomes faster.

---

## What does `WORKDIR /app` do?

Sets default working directory inside container.

Equivalent:

```bash id="’wini390"
cd /app
```

for all following instructions.

---

## Why use Gunicorn instead of `python app.py`?

Gunicorn is production-grade WSGI server.

Provides:

* multiple workers
* better concurrency
* better request handling
* improved performance

`python app.py` is mostly for development.

---

# Exercise 6 — Docker Layer Caching

## Why changing app.py does NOT rerun pip install?

Because:

```text id="’wini391"
requirements.txt layer did not change
```

Docker reuses cached layer.

Only changed layers rebuild.

---

## Rule for ordering Dockerfile instructions?

Place:

* stable instructions first
* frequently changing code later

Best practice:

```text id="’wini392"
Least changing → top
Most changing → bottom
```

to maximize caching efficiency.

---

# Exercise 7 — Image Sizes

## Difference between full and slim Python image?

`python:slim` is much smaller because unnecessary packages/tools removed.

Benefits:

* smaller downloads
* faster deployment
* lower storage usage

---

## Tradeoff of smaller images?

May miss:

* debugging tools
* build dependencies
* common Linux utilities

Sometimes additional packages must be installed manually.

---

## Why avoid ubuntu base for Python app?

Using:

```text id="’wini393"
python:slim
```

is better because:

* optimized for Python
* smaller image
* fewer vulnerabilities
* faster builds

Ubuntu adds unnecessary overhead.

---

# Exercise 8 — Port Forwarding

## Why app works inside container but not outside?

Without:

```bash id="’wini394"
-p host:container
```

container port exposed only inside container namespace.

Host machine cannot access container port directly.

---

## In ECS/EKS, what handles external traffic?

Usually:

* ALB (Application Load Balancer)
* NLB (Network Load Balancer)
* Kubernetes Ingress

handle external traffic routing.

---

# Exercise 9 — ENTRYPOINT

## When is `--entrypoint` useful?

Useful for:

* DB migrations
* debugging
* one-time scripts
* troubleshooting
* temporary startup overrides

Common in Kubernetes Jobs and ECS tasks.

---

## Difference between CMD and ENTRYPOINT?

## CMD

Provides default arguments/command.

Can be overridden easily.

---

## ENTRYPOINT

Defines fixed executable/container startup process.

Harder to override.

---

## Should ENTRYPOINT always be defined?

Not always.

Use ENTRYPOINT only when container has:

```text id="’wini395"
single fixed responsibility
```

Otherwise CMD provides more flexibility.

---

# Exercise 10 — Docker Hub

## Why Mac M1 images fail on EC2 sometimes?

Because architectures differ:

```text id="’wini396"
Mac M1 → ARM64
EC2 commonly → AMD64
```

Architecture mismatch causes runtime failure.

---

## In AWS, what registry is used instead of Docker Hub?

Use:

```text id="’wini397"
Amazon ECR (Elastic Container Registry)
```

Benefits:

* private registry
* IAM integration
* better security
* AWS-native integration
* faster pulls inside AWS

---

# Exercise 11 — Docker Compose

## Why use `postgres` hostname instead of localhost?

Docker Compose provides internal DNS.

Service name becomes hostname.

Inside app container:

```text id="’wini398"
localhost = app container itself
```

NOT PostgreSQL container.

---

## Why define volumes at bottom and reference inside service?

Bottom section:

```yaml id="’wini399"
volumes:
```

declares named volume globally.

Service section mounts volume into container.

Both are required.

---

## Why restart only 3 times?

Unlimited restarts may cause:

* infinite crash loops
* resource wastage
* noisy logs

Limited retries provide controlled recovery.

---

## Why Docker Compose not recommended for production?

Compose lacks:

* auto-scaling
* self-healing
* rolling deployments
* advanced scheduling
* orchestration
* HA clustering

Production systems use:

* Kubernetes
* ECS
* Swarm

instead.

---

# Exercise 12 — Startup Race Condition

## Why did Gunicorn sometimes hide failure?

Gunicorn retries workers automatically.

This sometimes delays visible crash behavior.

Without Gunicorn:

```text id="’wini400"
Application crashes immediately
```

making race condition obvious.

---

## What does `pg_isready` check?

Checks whether PostgreSQL:

```text id="’wini401"
is ready to accept client connections
```

not just whether container is running.

---

## What is `start_period`?

Grace period before healthcheck failures count.

Used because applications need startup time.

Prevents false unhealthy states during initialization.

---

# Final Interview Summary

## Containers

```text id="’wini402"
Containers are ephemeral and stateless by default.
```

---

## Volumes

```text id="’wini403"
Volumes provide persistent storage independent from container lifecycle.
```

---

## Docker Networking

```text id="’wini404"
Docker provides embedded DNS for container communication using service names.
```

---

## Docker Compose

```text id="’wini405"
Docker Compose simplifies multi-container application orchestration using declarative YAML configuration.
```

---

## Health Checks

```text id="’wini406"
Health checks validate application readiness, not just container startup.
```
