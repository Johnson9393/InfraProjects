# Difference Between `-v` and `--mount`

* Both `-v` and `--mount` are used to attach storage from host machine into Docker containers.
* `-v` is the older shorthand syntax mainly used for quick local testing.
* `--mount` is the newer structured syntax preferred in production and CI/CD environments.
* `--mount` is more readable, explicit, and safer for advanced configurations.
* `-v` may silently create missing host directories, whereas `--mount` throws proper validation errors.
* Real-world DevOps teams generally prefer `--mount` for production-grade Docker workflows.

---

# `-v` Command Example

```bash
docker run -it -v /Users/johnson/data:/app alpine sh
```

Meaning:

```text
Host Path                → Container Path
/Users/johnson/data      → /app
```

---

# `--mount` Command Example

```bash
docker run -it \
--mount type=bind,source=/Users/johnson/data,target=/app \
alpine sh
```

Both commands achieve the same result.

---

# Important Real-World Behaviors

## If file updates on Host

Changes immediately reflect inside container because both share the same filesystem.

Example:

```text
Host File Updated → Container Sees Updated File
```

---

## If file updates inside Container

Changes immediately appear on local machine because mounted path is shared.

Example:

```text
Container File Update → Host Sees Updated File
```

---

## If Container is Deleted

Data still remains on host machine because actual storage exists outside container.

---

## If New Container Uses Same Host Path

Example:

```bash
docker run -it -v /Users/johnson/data:/app ubuntu bash
```

New container will see existing files because both containers share same host storage.

---

# Real-World Use Cases

## Local Development

Developer edits code locally and container instantly reflects changes.

---

## Log Sharing

Application logs generated inside container directly appear on host machine.

---

## Persistent Data

Databases use mounted storage so data survives container deletion.

---

## CI/CD Pipelines

Build artifacts and configuration files are shared between host and containers.

---

# Interview One-Liner

```text
Docker bind mounts allow containers and host machines to share the same filesystem in real time, enabling persistent storage and live file synchronization.
```

# Docker Named Volumes

Named volumes are Docker-managed persistent storage used to store container data outside the container filesystem.

Unlike bind mounts, Docker itself manages the storage location internally.

---

# Create Named Volume

```bash
docker volume create my-volume
```

---

# Use Named Volume

```bash
docker run -it \
--mount type=volume,source=my-volume,target=/data \
alpine sh
```

OR

```bash
docker run -it -v my-volume:/data alpine sh
```

---

# Important Behavior

* Data persists even if container is deleted.
* Multiple containers can share the same volume.
* Docker manages the storage internally.
* Containers using same volume can access same files.

---

# Difference Between Bind Mount vs Named Volume

## Bind Mount

```text
Host filesystem managed manually by user
```

Example:

```bash
-v /host/path:/container/path
```

---

## Named Volume

```text
Docker-managed persistent storage
```

Example:

```bash
-v my-volume:/container/path
```

---

# Real-World Use Cases

* Database persistent storage
* Shared application data
* Container backups
* Production storage
* CI/CD persistent artifacts

---

# Important Interview Point

Named volumes are preferred in production because they are:

* Portable
* Docker-managed
* More secure
* Easier to backup
* Independent from host directory structure

---

# Useful Commands

## List Volumes

```bash
docker volume ls
```

---

## Inspect Volume

```bash
docker volume inspect my-volume
```

---

## Remove Volume

```bash
docker volume rm my-volume
```

---

# Interview One-Liner

```text
Docker named volumes provide persistent Docker-managed storage that survives container deletion and is commonly used for production data persistence.
```

