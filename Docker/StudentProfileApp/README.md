# Docker Two-Tier Application Setup (Flask + PostgreSQL)

# Objective

Run a Flask application and PostgreSQL database using Docker containers with:

* Custom Docker network
* Docker named volume
* Persistent PostgreSQL storage
* Container-to-container communication
* Port forwarding

This setup simulates a real-world two-tier application architecture.

---

# Architecture

```text
Browser
   ↓
localhost:8081
   ↓
Student App Container
   ↓
Docker Network (app-network)
   ↓
PostgreSQL Container
   ↓
Named Volume (pgdata)
```

---

# Important Docker Concepts Used

## Docker Network

Used for container-to-container communication.

Docker embedded DNS automatically resolves:

```text
postgres-db → PostgreSQL container IP
```

so application communicates using container name instead of IP address.

---

## Docker Named Volume

Used for persistent PostgreSQL data storage.

Even if PostgreSQL container is deleted:

```text
Database data remains safe inside volume.
```

---

# Step 1 — Create Docker Network

```bash
docker network create app-network
```

Verify:

```bash
docker network ls
```

Purpose:

```text
Allows app container and postgres container to communicate securely.
```

---

# Step 2 — Create Docker Named Volume

```bash
docker volume create pgdata
```

Verify:

```bash
docker volume ls
```

Purpose:

```text
Stores PostgreSQL data outside container filesystem for persistence.
```

---

# Step 3 — Run PostgreSQL Container

```bash
docker run -d \
--name postgres-db \
--network app-network \
-e POSTGRES_USER=postgres \
-e POSTGRES_PASSWORD=password \
-e POSTGRES_DB=studentdb \
-v pgdata:/var/lib/postgresql/data \
postgres:16
```

---

# Explanation

## `-d`

Runs container in background.

---

## `--name postgres-db`

Custom container name.

Used as DNS hostname inside Docker network.

---

## `--network app-network`

Attaches container to custom Docker network.

---

## `-e`

Sets environment variables.

```text
POSTGRES_USER      → DB username
POSTGRES_PASSWORD  → DB password
POSTGRES_DB        → Initial database
```

---

## `-v pgdata:/var/lib/postgresql/data`

Mounts Docker named volume.

```text
pgdata → Docker-managed persistent storage
```

mounted into PostgreSQL actual data directory.

---

## `postgres:16`

Uses fixed PostgreSQL version.

Production best practice is to pin image versions instead of using latest.

---

# Step 4 — Verify PostgreSQL Running

```bash
docker ps
```

Check logs:

```bash
docker logs postgres-db
```

Expected:

```text
database system is ready to accept connections
```

---

# Step 5 — Configure Flask Database Connection

Inside Flask application config:

```python
SQLALCHEMY_DATABASE_URI = "postgresql://postgres:password@postgres-db:5432/studentdb"
```

Important:

```text
postgres-db = container hostname
```

Docker DNS automatically resolves it.

---

# Why NOT localhost?

Inside containers:

```text
localhost = the container itself
```

NOT host machine.

Therefore application container cannot use:

```text
localhost:5432
```

to reach PostgreSQL container.

---

# Step 6 — Build Flask Application Image

From application directory:

```bash
docker build -t sp-app:1.0 .
```

Verify:

```bash
docker images
```

---

# Step 7 — Run Application Container

```bash
docker run -d \
--name student-app \
--network app-network \
-p 8081:8000 \
sp-app:1.0 \
python run.py
```

---

# Explanation

## `-p 8081:8000`

Port forwarding.

```text
Host Port      → Container Port
8081           → 8000
```

Application becomes accessible at:

```text
http://localhost:8081
```

---

## `python run.py`

Overrides default Docker CMD.

Used because:

```python
db.create_all()
```

exists inside:

```python
if __name__ == "__main__":
```

and executes only when running:

```text
python run.py
```

---

# Step 8 — Verify Application

Check running containers:

```bash
docker ps
```

Check logs:

```bash
docker logs student-app
```

Open browser:

```text
http://localhost:8081
```

Test:

* User registration
* Login
* Database operations

---

# Step 9 — Verify Persistent Storage

Remove PostgreSQL container:

```bash
docker rm -f postgres-db
```

Recreate container using SAME volume:

```bash
docker run -d \
--name postgres-db \
--network app-network \
-e POSTGRES_USER=postgres \
-e POSTGRES_PASSWORD=password \
-e POSTGRES_DB=studentdb \
-v pgdata:/var/lib/postgresql/data \
postgres:16
```

Result:

```text
All database data still exists.
```

Why?

Because:

```text
Data stored inside named volume, not container filesystem.
```

---

# Important Real-World Concepts

## Containers are Ephemeral

If data stored only inside container:

```text
Deleting container = losing data
```

---

## Named Volumes Solve Persistence

Volumes survive:

* Container deletion
* Container recreation
* Application restarts

---

# Docker Networking Concept

Containers inside same custom network communicate using:

```text
Container names
```

instead of IP addresses.

Example:

```text
student-app → postgres-db
```

---

# Common Debugging Commands

## Running Containers

```bash
docker ps
```

---

## All Containers

```bash
docker ps -a
```

---

## Container Logs

```bash
docker logs <container-name>
```

---

## Inspect Network

```bash
docker network inspect app-network
```

---

## Inspect Volume

```bash
docker volume inspect pgdata
```

---

# Common Issues Faced

## Using localhost for DB

Problem:

```text
Connection refused
```

Reason:

```text
localhost inside container points to same container.
```

Fix:

```text
Use postgres container name.
```

---

## PostgreSQL Version Mismatch

Problem:

```text
Old volume incompatible with new postgres image
```

Fix:

```bash
docker volume rm pgdata
```

and recreate clean volume.

---

# Interview One-Liners

## Docker Network

```text
Custom Docker bridge networks provide built-in DNS-based container communication using container names.
```

---

## Docker Named Volume

```text
Docker named volumes provide persistent Docker-managed storage independent from container lifecycle.
```

---

## Why Use Volumes?

```text
Containers are ephemeral, so persistent data like databases should always use volumes.
```

---

# Final Learning Outcome

This setup demonstrates real-world Docker concepts:

* Multi-container applications
* Persistent storage
* Docker networking
* Service discovery
* Container isolation
* Database persistence
* Runtime debugging
* Production-style architecture
