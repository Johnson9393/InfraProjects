# Docker Essential Commands

A practical Docker command reference for building images, creating/running containers, networking, volumes, logs, inspection, and cleanup.

---

## 1. Check Docker

```bash
docker version
```

Shows Docker client and server/engine versions.

```bash
docker info
```

Shows Docker Engine information, containers, images, storage driver, etc.

**Helpful when:** verifying Docker installation or troubleshooting the Docker daemon.

---

## 2. Build an Image

```bash
docker build -t shopsphere-frontend:1.0 .
```

Builds an image from the Dockerfile in the current directory.

* `-t` → gives the image a name/tag
* `.` → Docker build context

**Helpful when:** creating a Docker image from your application source.

---

## 3. Build a Specific Dockerfile

```bash
docker build -f Dockerfile.prod -t shopsphere-frontend:prod .
```

Uses a specific Dockerfile instead of the default `Dockerfile`.

**Helpful when:** a project has multiple Dockerfiles.

---

## 4. Build a Specific Stage

```bash
docker build --target development -t shopsphere-frontend-dev .
```

Builds only the `development` stage of a multi-stage Dockerfile.

**Helpful when:** you want a development image instead of the final production image.

Example:

```text
development → builder → production
```

`--target development` stops at the development stage.

---

## 5. List Images

```bash
docker images
```

Shows locally available Docker images.

```bash
docker image ls
```

Same purpose as `docker images`.

**Helpful when:** checking whether an image was successfully built.

---

## 6. Create a Container

```bash
docker create --name shopsphere-frontend shopsphere-frontend:1.0
```

Creates a container from an image but **does not start it**.

**Helpful when:** you want to separate container creation from container startup.

---

## 7. Start a Container

```bash
docker start shopsphere-frontend
```

Starts an existing stopped container.

When the container starts, its configured `ENTRYPOINT`/`CMD` process runs.

**Helpful when:** restarting an already-created container.

---

## 8. Create + Start a Container

```bash
docker run --name shopsphere-frontend shopsphere-frontend:1.0
```

`docker run` normally creates **and starts** a new container.

**Helpful when:** you want the simplest way to launch an application.

---

## 9. Run in Background

```bash
docker run -d --name shopsphere-frontend shopsphere-frontend:1.0
```

`-d` means detached mode.

The container runs in the background.

**Helpful when:** running services such as Nginx, APIs, databases, etc.

---

## 10. Port Mapping

```bash
docker run -d -p 8080:80 --name frontend shopsphere-frontend:1.0
```

Maps:

```text
Host port 8080 → Container port 80
```

So you access the application through:

```text
localhost:8080
```

**Helpful when:** accessing a containerized service from the host machine.

Important:

```text
EXPOSE 80
```

does **not** publish the port. `-p` actually publishes/maps it.

---

## 11. List Running Containers

```bash
docker ps
```

Shows currently running containers.

```bash
docker ps -a
```

Shows running **and stopped** containers.

**Helpful when:** checking container status.

---

## 12. Stop a Container

```bash
docker stop shopsphere-frontend
```

Gracefully stops a running container.

**Helpful when:** stopping an application.

---

## 13. Remove a Container

```bash
docker rm shopsphere-frontend
```

Removes a stopped container.

**Helpful when:** cleaning up old containers.

Force removal:

```bash
docker rm -f shopsphere-frontend
```

Stops and removes the container.

---

## 14. Container Logs

```bash
docker logs shopsphere-frontend
```

Shows container stdout/stderr logs.

Follow logs:

```bash
docker logs -f shopsphere-frontend
```

**Helpful when:** troubleshooting application startup or runtime problems.

---

## 15. Execute a Command Inside a Container

```bash
docker exec -it shopsphere-frontend sh
```

Opens a shell inside a running container.

**Helpful when:** debugging files, environment variables, processes, networking, etc.

For example:

```bash
ls
```

or:

```bash
cat /etc/nginx/conf.d/default.conf
```

---

## 16. Inspect a Container

```bash
docker inspect shopsphere-frontend
```

Shows detailed container configuration.

Includes things such as:

* Network configuration
* Mounts
* Environment
* IP address
* Image
* Startup configuration

**Helpful when:** troubleshooting container configuration.

---

# Docker Networks

## 17. List Networks

```bash
docker network ls
```

Shows Docker networks.

---

## 18. Create a Network

```bash
docker network create shopsphere-network
```

Creates a custom Docker network.

**Helpful when:** allowing multiple containers to communicate with each other.

---

## 19. Run Containers on a Network

```bash
docker run -d --network shopsphere-network --name frontend shopsphere-frontend:1.0
```

Connects the container to the specified network.

Another container can then communicate with it using the container/service name.

Example:

```text
frontend → api-gateway
```

rather than relying on changing container IP addresses.

---

## 20. Connect an Existing Container to a Network

```bash
docker network connect shopsphere-network frontend
```

Connects an already-created container to a network.

**Helpful when:** adding a running/existing container to another network.

---

# Docker Volumes

## 21. Create a Volume

```bash
docker volume create shopsphere-data
```

Creates Docker-managed persistent storage.

**Helpful when:** application data must survive container deletion.

---

## 22. List Volumes

```bash
docker volume ls
```

Shows Docker volumes.

---

## 23. Mount a Volume

```bash
docker run -d \
  --name postgres \
  -v shopsphere-data:/var/lib/postgresql/data \
  postgres
```

Maps:

```text
Docker volume
      ↓
/var/lib/postgresql/data
```

inside the container.

If the PostgreSQL container is deleted, the volume can remain.

**Helpful for:** databases and other stateful data.

---

## 24. Bind Mount

```bash
docker run -v $(pwd):/app shopsphere-frontend-dev
```

Maps a host directory directly into the container.

```text
Host directory → Container directory
```

**Helpful for:** local development, source-code sharing, configuration files, etc.

### Volume vs Bind Mount

```text
Volume
Docker manages the storage.

Bind mount
You explicitly choose the host path.
```

---

# Image / Container Inspection

## 25. Image History

```bash
docker history shopsphere-frontend:1.0
```

Shows image layers and the Dockerfile instructions that created them.

**Helpful when:** understanding image size and layers.

---

## 26. Inspect an Image

```bash
docker inspect shopsphere-frontend:1.0
```

Shows detailed image metadata.

**Helpful when:** checking image configuration, environment, entrypoint, command, architecture, etc.

---

# Pull and Push

## 27. Pull an Image

```bash
docker pull nginx:alpine
```

Downloads an image from a container registry.

**Helpful when:** obtaining base images or existing application images.

---

## 28. Tag an Image

```bash
docker tag shopsphere-frontend:1.0 \
  <registry>/shopsphere-frontend:1.0
```

Creates another name/tag pointing to the image.

**Helpful when:** preparing an image for a registry such as Amazon ECR.

---

## 29. Push an Image

```bash
docker push <registry>/shopsphere-frontend:1.0
```

Uploads the image to a container registry.

Typical production flow:

```text
Docker build
     ↓
Tag
     ↓
Push
     ↓
ECR
     ↓
EKS
```

---

# Cleanup

## 30. Remove an Image

```bash
docker rmi shopsphere-frontend:1.0
```

Removes a Docker image that is no longer needed.

---

## 31. Remove Stopped Containers

```bash
docker container prune
```

Removes stopped containers.

---

## 32. Remove Unused Images

```bash
docker image prune
```

Removes dangling/unused images.

---

## 33. General Cleanup

```bash
docker system prune
```

Removes unused Docker resources such as stopped containers, unused networks, and dangling images.

Use carefully.

---

# The Commands You Should Know First

For day-to-day DevOps work, remember these first:

```text
docker build
docker build --target
docker images
docker run
docker create
docker start
docker ps
docker stop
docker rm
docker logs
docker exec
docker inspect
docker network create
docker network ls
docker volume create
docker volume ls
docker pull
docker tag
docker push
docker rmi
```

## Most Important Mental Model

```text
Dockerfile
    ↓
docker build
    ↓
Docker Image
    ↓
docker create
    ↓
Container
    ↓
docker start
    ↓
Application process
```

Or simply:

```text
Image = packaged application

Container = running instance of an image

Volume = persistent data

Network = container-to-container communication

Registry = place to store/share images
```
