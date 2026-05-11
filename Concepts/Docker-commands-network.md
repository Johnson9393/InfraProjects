# Docker Essentials for DevOps Interviews

# What is Docker?

Docker is a containerization platform used to package applications along with their dependencies into lightweight isolated environments called containers.

Containers ensure applications run consistently across:

* Local machines
* Servers
* Cloud environments
* CI/CD pipelines

---

# Important Docker Components

## Docker Engine

Core runtime responsible for:

* Building images
* Running containers
* Managing networks and storage

---

## Docker Image

A read-only template used to create containers.

Example:

```bash
nginx
ubuntu
alpine
```

---

## Docker Container

A running instance of a Docker image.

Example:

```text
Image → Container
```

---

# Common Docker Commands

## Check Docker Version

```bash
docker --version
```

Displays installed Docker version.

---

## Pull Image from Docker Hub

```bash
docker pull nginx
```

Downloads image locally.

---

## Run Container

```bash
docker run nginx
```

Creates and starts container.

---

## Run Container with Custom Name

```bash
docker run --name my-nginx nginx
```

Creates container with custom name.

---

## Run Container in Background

```bash
docker run -d --name my-nginx nginx
```

`-d` = detached/background mode.

---

## Port Mapping

```bash
docker run -d -p 8080:80 nginx
```

Maps:

```text
Host Port → Container Port
8080      → 80
```

Access application:

```text
http://localhost:8080
```

---

## Interactive Container

```bash
docker run -it ubuntu bash
```

`-it` provides terminal access inside container.

---

## List Running Containers

```bash
docker ps
```

---

## List All Containers

```bash
docker ps -a
```

---

## Stop Container

```bash
docker stop my-nginx
```

---

## Start Container

```bash
docker start my-nginx
```

---

## Restart Container

```bash
docker restart my-nginx
```

---

## Remove Container

```bash
docker rm my-nginx
```

---

## Remove Image

```bash
docker rmi nginx
```

---

## View Container Logs

```bash
docker logs my-nginx
```

---

## Access Running Container

```bash
docker exec -it my-nginx bash
```

Executes shell inside container.

---

# Docker Networking Concepts

Docker provides networking for communication between:

* Containers
* Host machine
* External world

---

# Types of Docker Networks

## 1. Bridge Network (Default)

Default Docker network.

When container is created without specifying network:

```bash
docker run nginx
```

Docker automatically attaches container to:

```text
bridge network
```

Features:

* Containers receive private IPs
* Basic container communication
* NAT-based internet access

Example container IP:

```text
172.17.x.x
```

---

# Important Interview Concept

Default bridge network mainly supports:

```text
IP-based communication
```

Container name resolution may work partially in newer Docker versions but is not considered reliable for production service discovery.

---

## 2. User-Defined Bridge Network

Recommended approach.

Create network:

```bash
docker network create my-net
```

Run containers:

```bash
docker run -dit --name c1 --network my-net alpine
```

```bash
docker run -dit --name c2 --network my-net alpine
```

Now containers communicate using:

```text
Container names
```

Example:

```bash
ping c2
```

Why?

Docker provides:

```text
Embedded DNS-based service discovery
```

Benefits:

* Stable communication
* Better isolation
* Reliable DNS resolution
* Production-friendly networking

---

## 3. Host Network

Container shares host network directly.

No network isolation.

Mostly used in Linux environments.

---

## 4. None Network

Container gets no networking.

Used for highly isolated workloads.

---

# Docker DNS Concept

In custom bridge networks Docker automatically maps:

```text
Container Name → Container IP
```

Example:

```text
mysql → 172.18.0.5
backend → 172.18.0.6
```

Applications communicate using container names instead of IPs.

---

# Important Real-World Concept

IPs are dynamic and may change after container restart.

Therefore production environments use:

```text
DNS-based communication
```

instead of hardcoded IPs.

---

# Docker Inspect Command

```bash
docker inspect <container-name>
```

Used to view:

* IP address
* Network details
* Mounts
* Environment variables
* Container metadata

---

# Docker Logs and Troubleshooting

## View logs

```bash
docker logs <container>
```

---

## Real-time logs

```bash
docker logs -f <container>
```

---

# Docker Exec

Access running container shell:

```bash
docker exec -it <container> bash
```

Alpine uses:

```bash
sh
```

instead of bash.

Example:

```bash
docker exec -it alpine1 sh
```

---

# Real DevOps Usage of Docker

Docker is commonly used for:

* Microservices
* CI/CD pipelines
* Kubernetes workloads
* Local development
* Testing environments
* Application packaging

---

# Important Interview One-Liners

## Docker

```text
Docker is a containerization platform used to package applications and dependencies into isolated portable environments called containers.
```

---

## Docker Image

```text
Docker image is a read-only template used to create containers.
```

---

## Container

```text
A container is a running instance of a Docker image.
```

---

## Bridge Network

```text
Bridge network is Docker’s default private network used for container communication.
```

---

## Custom Bridge Network

```text
User-defined bridge networks provide built-in DNS-based service discovery between containers.
```

---

# Final Summary

Docker simplifies:

* Application deployment
* Environment consistency
* Infrastructure portability
* CI/CD workflows
* Microservices architecture

Modern DevOps and cloud-native applications heavily rely on Docker containers and Docker networking concepts.
