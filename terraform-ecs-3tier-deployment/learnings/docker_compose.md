# Docker Compose Explained in Simple Terms

## Objective

The purpose of this `docker-compose.yml` file is to run the complete application locally using multiple containers.

Instead of starting each container manually, Docker Compose starts and manages all application components together.

In this project, Docker Compose runs:

```text
Frontend Container
       │
       ▼
Backend Container
       │
       ▼
PostgreSQL Database Container
```

A single command:

```bash
docker compose up -d
```

can start the entire application stack.

---

# Dockerfile vs Docker Compose

A common interview question is:

### Why do we need Docker Compose if we already have Dockerfiles?

## Dockerfile

A Dockerfile is responsible for:

```text
Building a Docker Image
```

Examples:

```text
Frontend Dockerfile
       ↓
Frontend Image

Backend Dockerfile
       ↓
Backend Image
```

A Dockerfile knows how to build one image.

---

## Docker Compose

Docker Compose is responsible for:

```text
Running Multiple Containers Together
```

It defines:

* Which containers should run
* Which ports should be exposed
* Which environment variables should be used
* Which services depend on other services
* Which networks and volumes should be created

---

## Simple Analogy

Think of a restaurant:

```text
Chef
Waiter
Cashier
```

Dockerfiles explain:

```text
How to create a Chef
How to create a Waiter
How to create a Cashier
```

Docker Compose explains:

```text
How Chef, Waiter and Cashier work together
```

---

# High-Level Architecture

```text
Browser
   │
   ▼
Frontend Container
   │
   ▼
Backend Container
   │
   ▼
PostgreSQL Container
```

---

# Services Section

```yaml
services:
```

Defines all containers that Docker Compose should manage.

This project contains:

```text
db
backend
frontend
```

---

# Database Service

```yaml
db:
```

Creates a PostgreSQL container.

---

## Image

```yaml
image: postgres:13
```

Downloads and runs:

```text
PostgreSQL Version 13
```

---

## Environment Variables

```yaml
POSTGRES_DB: devops_learning
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
```

Automatically creates:

```text
Database : devops_learning
User     : postgres
Password : postgres
```

during startup.

---

## Volume

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```

Stores database files outside the container.

### Without Volume

```text
Container Deleted
      ↓
Database Lost
```

---

### With Volume

```text
Container Deleted
      ↓
Data Remains
```

This is called Persistent Storage.

---

## Port Mapping

```yaml
5432:5432
```

Meaning:

```text
Laptop Port 5432
      ↓
Container Port 5432
```

Allows local database access.

---

# Database Health Check

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
```

---

## Why Health Checks?

A container may be:

```text
Running
```

but the application inside may not be:

```text
Ready
```

Health checks verify application readiness.

---

## pg_isready

```bash
pg_isready -U postgres
```

asks PostgreSQL:

```text
"Are you ready to accept database connections?"
```

If PostgreSQL responds successfully:

```text
Healthy
```

Otherwise:

```text
Unhealthy
```

---

## CMD-SHELL

```yaml
CMD-SHELL
```

runs the command through Linux shell.

Equivalent:

```bash
/bin/sh -c "pg_isready -U postgres"
```

Useful when running shell commands.

---

## Interval

```yaml
interval: 10s
```

Run health check every:

```text
10 seconds
```

---

## Timeout

```yaml
timeout: 5s
```

Maximum wait time:

```text
5 seconds
```

before marking the attempt as failed.

---

## Retries

```yaml
retries: 5
```

Allow:

```text
5 consecutive failures
```

before marking container unhealthy.

---

# Backend Service

```yaml
backend:
```

Creates backend container.

---

## Build

```yaml
build: ./backend
```

Uses:

```text
backend/Dockerfile
```

to build backend image.

Equivalent:

```bash
docker build ./backend
```

---

## Volume Mount

```yaml
./backend:/app
```

Maps local source code into container.

Meaning:

```text
Laptop Backend Folder
         ↓
Container /app
```

Useful during development.

Changes appear instantly without rebuilding.

---

## Environment Variables

### FLASK_APP

```yaml
FLASK_APP=run.py
```

Main Flask application file.

---

### FLASK_DEBUG

```yaml
FLASK_DEBUG=1
```

Enables:

* Auto reload
* Detailed error messages

Development use only.

---

### DATABASE_URL

```yaml
postgresql://postgres:postgres@db:5432/devops_learning
```

Database connection string.

Breakdown:

```text
Username : postgres
Password : postgres
Host     : db
Port     : 5432
Database : devops_learning
```

---

## Why Host = db?

Because Docker Compose automatically creates internal DNS.

Service:

```yaml
db:
```

becomes reachable as:

```text
db
```

inside the Docker network.

No IP addresses required.

---

## Secret Key

```yaml
SECRET_KEY
```

Used by Flask for:

* Sessions
* Cookies
* Authentication

---

## ALLOWED_ORIGINS

```yaml
ALLOWED_ORIGINS=http://localhost:3000
```

CORS configuration.

Allows browser communication between:

```text
Frontend
     ↓
Backend API
```

Without this:

```text
Browser blocks requests
```

---

## Port Mapping

```yaml
8000:8000
```

Meaning:

```text
Laptop Port 8000
      ↓
Backend Port 8000
```

---

# Backend Dependency

```yaml
depends_on:
  db:
    condition: service_healthy
```

Meaning:

```text
Do not start Backend
until Database becomes Healthy
```

Flow:

```text
Database Starts
      ↓
Health Check Passes
      ↓
Backend Starts
```

---

# Backend Startup Command

```yaml
bash -c "sleep 10 && ./migrate.sh && gunicorn --bind 0.0.0.0:8000 run:app"
```

---

## sleep 10

Wait:

```text
10 seconds
```

to allow database startup.

---

## migrate.sh

Runs database migrations.

Examples:

```text
Create Tables
Update Schema
Apply Database Changes
```

---

## Gunicorn

Starts production Flask server.

```bash
gunicorn --bind 0.0.0.0:8000 run:app
```

Meaning:

```text
Run Flask App
Listen on Port 8000
Accept External Connections
```

---

# Backend Health Check

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/api"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

---

## curl

```bash
curl http://localhost:8000/api
```

Sends an HTTP request to backend API.

Docker asks:

```text
"Can the API respond successfully?"
```

---

## -f

```bash
curl -f
```

Means:

```text
Fail if HTTP error occurs
```

Only successful responses count as healthy.

Example:

```text
200 OK
```

Healthy.

---

Example:

```text
500 Internal Server Error
```

Unhealthy.

---

## start_period

```yaml
start_period: 40s
```

Means:

```text
Ignore failures
for first 40 seconds
```

Why?

Because backend startup takes time:

```text
Start Container
      ↓
Connect Database
      ↓
Run Migrations
      ↓
Start Gunicorn
```

Without start_period:

```text
Health Check Runs Too Early
      ↓
False Failures
```

---

# Frontend Service

```yaml
frontend:
```

Creates frontend container.

---

## Build

```yaml
build: ./frontend
```

Uses:

```text
frontend/Dockerfile
```

to build frontend image.

---

## Port Mapping

```yaml
3000:80
```

Meaning:

```text
Browser
   ↓
localhost:3000
   ↓
Frontend Container Port 80
```

---

## Backend URL

```yaml
BACKEND_URL=http://backend:8000
```

Defines where frontend sends API requests.

---

## Why backend?

Docker Compose automatically creates DNS.

Service:

```yaml
backend:
```

becomes:

```text
backend
```

inside Docker network.

Frontend can simply call:

```text
http://backend:8000
```

without knowing IP addresses.

---

## Frontend Dependency

```yaml
depends_on:
  - backend
```

Meaning:

```text
Start Backend First
Then Start Frontend
```

---

# Named Volume

```yaml
volumes:
  postgres_data:
```

Creates persistent Docker volume.

Used by:

```text
PostgreSQL Database
```

to store data permanently.

---

# Complete Startup Flow

When running:

```bash
docker compose up -d
```

Docker performs:

```text
1. Start PostgreSQL Container
2. Run Database Health Check
3. Wait Until Database Healthy
4. Start Backend Container
5. Wait 10 Seconds
6. Run Database Migrations
7. Start Gunicorn
8. Run Backend Health Check
9. Start Frontend Container
10. Application Ready
```

---

# Complete Request Flow

When user opens:

```text
http://localhost:3000
```

Flow:

```text
Browser
   │
   ▼
Frontend Container
   │
   ▼
http://backend:8000
   │
   ▼
Backend Container
   │
   ▼
db:5432
   │
   ▼
PostgreSQL Container
```

---

# How This Relates to ECS

Docker Compose is primarily used for:

```text
Local Development
Testing
Learning
```

In production:

```text
Docker Compose
      ↓
Replaced By
      ↓
ECS Task Definitions
ECS Services
Service Connect
ALB
RDS
```

The same concepts still apply:

* Service Discovery
* Environment Variables
* Health Checks
* Dependencies
* Networking

Only the platform changes.

---

# Interview Summary

If asked:

"What is Docker Compose and why did you use it?"

You can answer:

> Docker Compose is used to define and run multi-container applications. In my project, it orchestrates three services: PostgreSQL, Flask Backend, and React Frontend. It manages container startup order, networking, environment variables, health checks, volumes, and service communication. It allows me to run the complete application stack locally using a single command while simulating how the services will interact later in ECS or Kubernetes.
