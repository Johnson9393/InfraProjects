# Python Dockerfile — Production & Interview Reference

## Production-Oriented Python Dockerfile

A typical Python service can use a multi-stage build when dependencies require compilation:

```
FROM python:3.12-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim

WORKDIR /app

COPY --from=builder /usr/local/lib/python3.12/site-packages \
    /usr/local/lib/python3.12/site-packages

COPY . .

RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["python", "app.py"]
```

---

# 1. Multi-Stage Build

The build stage contains tools required to install/compile dependencies.

The runtime stage contains only what is required to run the Python application.

```
Build stage
    ↓
Install/compile dependencies
    ↓
Runtime stage
    ↓
Copy installed dependencies + application
    ↓
Run application
```

Benefits:

* Smaller runtime image.
* Build tools don't need to remain in the final image.
* Reduced attack surface.
* Cleaner production image.

Important:

> Multi-stage is especially useful when Python dependencies require native compilation.

If all dependencies are pure Python and no build tools are required, a single-stage image may sometimes be sufficient.

---

# 2. `python:3.12-slim`

`slim` is a smaller Debian-based Python image.

It provides Python while removing many unnecessary packages compared with a full Debian/Python image.

Benefits:

* Smaller image.
* Fewer unnecessary packages.
* Still provides a Debian-based environment compatible with many Python packages.

---

# 3. `WORKDIR /app`

Sets `/app` as the working directory.

All following relative commands operate from this directory.

It keeps application files organized.

---

# 4. `apt-get install`

Example:

```
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

### `apt-get update`

Downloads the Debian package repository index so APT knows which packages and versions are available.

### `apt-get install`

Installs required OS-level packages.

### `gcc`

A C compiler.

Some Python packages contain native C/C++ extensions and may need a compiler during installation.

### `postgresql-client`

Provides PostgreSQL client utilities.

Only install it if the application/image actually requires PostgreSQL command-line tools.

A Python application connecting to PostgreSQL does not automatically require the PostgreSQL CLI.

### `curl`

Command-line HTTP client.

Useful for debugging or health-check related tasks if actually required.

It should not be installed unnecessarily.

### `rm -rf /var/lib/apt/lists/*`

Removes APT's downloaded package indexes after installation.

The installed packages remain.

Purpose:

> Reduce unnecessary image size.

---

# 5. `COPY requirements.txt .`

Copies the Python dependency definition into `/app`.

Example:

```
Flask
psycopg2
requests
```

Copying the dependency file separately helps Docker caching.

If application source changes but `requirements.txt` doesn't:

```
requirements.txt unchanged
      ↓
pip install layer can be reused
      ↓
Source layer rebuilds
```

This avoids reinstalling dependencies unnecessarily.

---

# 6. `pip install --no-cache-dir -r requirements.txt`

Installs the Python dependencies listed in `requirements.txt`.

### `pip`

Python package manager.

### `-r requirements.txt`

Tells pip to read dependencies from `requirements.txt`.

### `--no-cache-dir`

Prevents pip from retaining downloaded package cache files.

Important:

> The Python packages are still installed. Only the unnecessary download cache is avoided.

Equivalent concept:

```
requirements.txt
      ↓
pip install
      ↓
Python packages installed
      ↓
No pip download cache retained
```

---

# 7. Python Dependency Layer Caching

Recommended ordering:

```
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
```

Why?

Docker caches layers.

If only application source changes, the dependency installation layer can remain cached.

This is an important Docker optimization and interview point.

---

# 8. Runtime Stage

The runtime stage should contain:

* Python runtime.
* Required runtime dependencies.
* Application source/code.
* Required runtime OS libraries.

It should not contain unnecessary build tools such as compilers if they aren't required at runtime.

Example:

```
FROM python:3.12-slim
```

---

# 9. Copying Dependencies from Builder

The builder installs dependencies.

The runtime stage copies the installed Python packages:

```
COPY --from=builder \
    /usr/local/lib/python3.12/site-packages \
    /usr/local/lib/python3.12/site-packages
```

This allows the final image to use the dependencies without installing build tools again.

Important:

> The exact Python path depends on the Python version/base image, so it should be verified rather than blindly copied.

---

# 10. `COPY . .`

Copies the application source code into the runtime image.

`.dockerignore` should prevent unnecessary files from entering the build context.

Typical exclusions:

```
.git
.env
.env.*
*.log
__pycache__/
.pytest_cache/
.venv/
tests/
coverage/
.idea/
.vscode/
README.md
```

`.dockerignore` does not delete these files from Git.

It only prevents them from being sent as part of the Docker build context.

---

# 11. Non-Root User

Example:

```
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser
```

Creates a dedicated non-root Linux user.

### `useradd`

Creates the user.

### `-m`

Creates the user's home directory.

### `-u 1000`

Assigns UID 1000.

`1000` is not special. Another unused UID can be used.

### `chown`

Changes ownership of `/app` to the application user.

### `USER appuser`

Runs the application as `appuser` instead of root.

Purpose:

> Follow the principle of least privilege and avoid running the application as root.

---

# 12. `EXPOSE`

```
EXPOSE 8000
```

Documents the port used by the Python application.

Important:

> `EXPOSE` does not publish the port.

It is documentation/metadata about the expected container port.

---

# 13. `CMD`

Example:

```
CMD ["python", "app.py"]
```

Defines the default command used to start the Python application.

It can be replaced at runtime.

Concept:

```
CMD = default startup command
```

Unlike Node.js, Python does not automatically require `dumb-init`.

An init process can still be used when the application's process-management requirements justify it.

---

# 14. `ENTRYPOINT` vs `CMD`

### CMD

```
CMD ["python", "app.py"]
```

Provides the default command.

It can be easily replaced:

```
docker run image /bin/sh
```

### ENTRYPOINT

```
ENTRYPOINT ["python"]
```

Makes Python the main executable.

Then:

```
CMD ["app.py"]
```

provides the default argument.

Together:

```
ENTRYPOINT ["python"]
CMD ["app.py"]
```

results in:

```
python app.py
```

If runtime arguments are supplied, CMD can be replaced while the ENTRYPOINT remains.

ENTRYPOINT can also be explicitly overridden:

```
docker run --entrypoint /bin/sh image
```

Interview summary:

> **ENTRYPOINT defines the main executable; CMD provides the default command/arguments.**

---

# 15. `.dockerignore`

Use `.dockerignore` to prevent unnecessary files from entering the build context.

For Python, commonly exclude:

```
.git
.env
.env.*
__pycache__/
.pytest_cache/
.venv/
*.pyc
*.log
tests/
coverage/
.idea/
.vscode/
README.md
```

This improves build efficiency and prevents unnecessary files from being included in the image.

---

# 16. Image-Level Security

For the Docker image itself:

* Use a minimal base image.
* Use multi-stage builds where useful.
* Run as non-root.
* Don't bake secrets into the image.
* Use `.dockerignore`.
* Install only required OS packages.
* Install only required Python dependencies.
* Clean APT/pip caches.
* Prefer pinned base-image versions instead of `latest`.
* Keep the base image and Python dependencies maintained.

Runtime controls such as Kubernetes capabilities, seccomp, resource limits and read-only filesystems belong to the runtime/Kubernetes layer.

---

# 17. Python vs Node.js — Important Difference

Node.js commonly uses:

```
dumb-init
```

when an init process is useful for proper PID 1 behavior, signal forwarding and child-process reaping.

Python does not automatically require `dumb-init`.

The decision depends on the application's process model.

The important concept is:

> `dumb-init` is a process-management tool, not a requirement of a particular programming language.

---

# 18. Interview Mental Model

When asked to design an optimized Python Docker image:

```
1. Choose a small Python base image.
2. Use multi-stage if dependencies need build tools.
3. Set WORKDIR.
4. Copy requirements.txt first.
5. Install dependencies with pip.
6. Avoid pip cache.
7. Use a clean runtime stage.
8. Copy only required runtime dependencies.
9. Copy application source.
10. Create a non-root user.
11. Change ownership where required.
12. Run as the non-root user.
13. EXPOSE the application port.
14. Start using CMD or ENTRYPOINT appropriately.
```

### One-line interview answer

> **I would use a slim Python image, multi-stage builds when native dependencies require compilation, copy requirements first for Docker layer caching, install dependencies without retaining pip cache, keep build tools out of the runtime image, use a minimal runtime image, run as a non-root user, avoid secrets in the image, and use CMD/ENTRYPOINT appropriately for application startup.**
