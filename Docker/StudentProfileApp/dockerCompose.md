# Docker Compose - Two Tier Flask + PostgreSQL Application

# Objective

Run a multi-container application using Docker Compose with:

* Flask application
* PostgreSQL database
* Docker volumes
* Docker networking
* Health checks
* Restart policies

---

# Architecture

```text
Browser
   ↓
localhost:8081
   ↓
Flask App Container
   ↓
Docker Network (app-network)
   ↓
PostgreSQL Container
   ↓
Named Volume (pgdata)
```

---

# Why Docker Compose?

Instead of manually running:

```bash
docker network create
docker volume create
docker run postgres
docker run app
```

Docker Compose automates everything using one YAML file.

---

# docker-compose.yaml

```yaml
services:

  postgres:
    image: postgres:16

    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: studentdb

    volumes:
      - pgdata:/var/lib/postgresql/data

    networks:
      - app-network

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d studentdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  app:
    build:
      context: .

    ports:
      - "8081:8000"

    environment:
      DATABASE_URL: postgresql://postgres:password@postgres:5432/studentdb

    command: python run.py

    networks:
      - app-network

    depends_on:
      postgres:
        condition: service_healthy

    restart: on-failure:3

volumes:
  pgdata:

networks:
  app-network:
```

---

# Important Concepts

## services

Defines all containers.

```yaml
services:
```

---

## build

Builds image using local Dockerfile.

```yaml
build:
  context: .
```

Equivalent:

```bash
docker build .
```

---

## environment

Passes environment variables into containers.

```yaml
environment:
```

Used for:

* DB credentials
* Connection strings
* App configs

---

## ports

Maps host port to container port.

```yaml
ports:
  - "8081:8000"
```

Meaning:

```text
Host 8081 → Container 8000
```

Access app:

```text
http://localhost:8081
```

---

## volumes

Provides persistent storage.

```yaml
volumes:
  - pgdata:/var/lib/postgresql/data
```

Important:

```text
Deleting container does NOT delete DB data.
```

---

## networks

Custom Docker network for container communication.

```yaml
networks:
  - app-network
```

Containers communicate using service names:

```text
app → postgres
```

Docker embedded DNS resolves service names automatically.

---

## healthcheck

Checks if PostgreSQL is actually ready.

```yaml
healthcheck:
```

Container running does NOT always mean application is ready.

`pg_isready` validates DB connectivity.

---

## depends_on

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

Starts app only after PostgreSQL becomes healthy.

Prevents startup race conditions.

---

## command

Overrides Dockerfile CMD.

```yaml
command: python run.py
```

Used because:

```python
db.create_all()
```

runs only inside:

```python
if __name__ == "__main__":
```

---

## restart

```yaml
restart: on-failure:3
```

Restarts failed container 3 times automatically.

Useful for transient failures.

---

# Commands Used

## Start Compose

```bash
docker compose up
```

---

## Build + Start

```bash
docker compose up --build
```

Used after code/config changes.

---

## Run in Background

```bash
docker compose up -d
```

---

## Stop Containers

```bash
docker compose down
```

Removes:

* containers
* compose network

Keeps volumes safe.

---

## Remove Everything Including Volumes

```bash
docker compose down -v
```

Deletes:

* containers
* networks
* named volumes

Database resets completely.

---

## View Running Containers

```bash
docker compose ps
```

---

## View Logs

```bash
docker compose logs
```

---

## Check Docker Volumes

```bash
docker volume ls
```

---

## Inspect Volume

```bash
docker volume inspect pgdata
```

---

## Check Networks

```bash
docker network ls
```

---

## Inspect Network

```bash
docker network inspect app-network
```

---

# Important Learning

## localhost inside container

```text
localhost = same container
```

NOT host machine.

So app cannot use:

```text
localhost:5432
```

to connect PostgreSQL container.

Correct hostname:

```text
postgres
```

because service name becomes DNS hostname.

---

# Real-World Benefits of Docker Compose

* Multi-container management
* Local development
* Integration testing
* Environment consistency
* Simplified deployments
* Faster onboarding

---

# Interview One-Liners

## Docker Compose

```text
Docker Compose is used to define and manage multi-container Docker applications using a declarative YAML configuration.
```

---

## Docker Volumes

```text
Named volumes provide persistent Docker-managed storage independent of container lifecycle.
```

---

## Docker Networks

```text
Custom Docker networks provide automatic DNS-based container communication using service names.
```

---

## Health Checks

```text
Health checks ensure dependent services start only after applications become fully ready.
```

---

# Final Outcome

Successfully implemented:

* Flask container
* PostgreSQL container
* Persistent storage
* Docker networking
* Health checks
* Restart policies
* Service discovery
* Multi-container orchestration using Docker Compose
