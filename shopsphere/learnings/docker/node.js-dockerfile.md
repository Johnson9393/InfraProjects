# Node.js Dockerfile — Production & Interview Reference

## Production-Oriented Node.js Dockerfile

A typical optimized Node.js service can use a multi-stage build:

* **Build stage** → install production dependencies.
* **Runtime stage** → use a clean minimal image and copy only what is required to run the application.

Example:

```
FROM node:18-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

FROM node:18-alpine
WORKDIR /app

RUN apk add --no-cache dumb-init

COPY --from=builder /app/node_modules ./node_modules
COPY . .

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 8002

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
```

---

## 1. Multi-Stage Build

### Why?

Separate the build/dependency environment from the final runtime image.

```
Build stage
    ↓
Install dependencies
    ↓
Runtime stage
    ↓
Copy only required files
```

Benefits:

* Smaller final image.
* Fewer unnecessary tools/packages.
* Reduced attack surface.
* Cleaner production image.

---

## 2. Layer Ordering & Docker Cache

Dependency files are copied before application source:

```
COPY package*.json ./
RUN npm install --omit=dev

COPY . .
```

Why?

Docker caches layers.

If only application source changes:

```
package.json unchanged
      ↓
npm install layer can be reused
      ↓
only COPY . . needs rebuilding
```

This avoids reinstalling dependencies unnecessarily.

**Interview point:**

> Copy dependency manifests before source code so dependency installation can be cached independently from application source changes.

---

## 3. `npm install --omit=dev`

```
RUN npm install --omit=dev
```

`npm install` installs dependencies from `package.json` / `package-lock.json`.

`--omit=dev` means:

> Install production dependencies but skip `devDependencies`.

Example:

```
dependencies
├── express       → installed
└── pg            → installed

devDependencies
├── jest          → skipped
└── eslint        → skipped
```

This keeps the production image smaller and avoids unnecessary development packages.

---

## 4. `npm cache clean --force`

```
npm cache clean --force
```

Removes npm's package download cache after installation.

Important:

> It does NOT remove the installed `node_modules`.

It only removes unnecessary cached package data to reduce image size.

---

## 5. `apk add --no-cache dumb-init`

```
RUN apk add --no-cache dumb-init
```

`apk` is Alpine's package manager.

`dumb-init` is a small **init process** used as PID 1 inside the container.

It helps with:

* Signal forwarding.
* Graceful application shutdown.
* Reaping orphan/zombie child processes.

Container without `dumb-init`:

```
Container
   ↓
Node.js (PID 1)
   ↓
Application
```

With `dumb-init`:

```
Container
   ↓
dumb-init (PID 1)
   ↓
Node.js
   ↓
Application
```

For example, when the container receives `SIGTERM`, `dumb-init` forwards the signal to Node.js so the application can perform graceful shutdown.

Important:

> `dumb-init` is an init process inside the container, NOT a Kubernetes init container.

Also:

`--no-cache` means Alpine does not retain its package-manager cache/index. The installed `dumb-init` remains in the image.

---

## 6. Non-Root User

```
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

RUN chown -R nodejs:nodejs /app

USER nodejs
```

Creates a dedicated non-root user and runs the application with it.

Why?

> The application should not run with root privileges.

`1001` is not special. Another unused UID/GID can be used.

The important concept is:

```
Root (UID 0)       → avoid
Dedicated user     → preferred
```

---

## 7. `EXPOSE`

```
EXPOSE 8002
```

Documents that the application listens on port `8002`.

Important:

> `EXPOSE` does NOT publish the port.

Port publishing is done at runtime, for example with Docker:

```
docker run -p 8002:8002 image
```

---

# 8. ENTRYPOINT vs CMD

## ENTRYPOINT

```
ENTRYPOINT ["dumb-init", "--"]
```

Defines the main executable that should run when the container starts.

Here:

```
dumb-init
```

becomes PID 1.

## CMD

```
CMD ["node", "src/index.js"]
```

Provides the default command/arguments.

Together:

```
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
```

effectively results in:

```
dumb-init -- node src/index.js
```

---

## CMD Can Be Overridden

Given:

```
CMD ["node", "src/index.js"]
```

Running:

```
docker run image /bin/sh
```

replaces the CMD.

The container runs `/bin/sh` instead of the Node application.

So:

> CMD = default command/arguments.

---

## ENTRYPOINT Can Also Be Overridden

ENTRYPOINT is not absolutely unchangeable.

It can be explicitly overridden:

```
docker run --entrypoint /bin/sh image
```

Now `/bin/sh` becomes the entrypoint.

So the accurate interview statement is:

> CMD is easily replaced by the runtime command, while ENTRYPOINT defines the main executable and requires explicit `--entrypoint` to replace it.

---

# 9. Common ENTRYPOINT + CMD Pattern

A common production pattern is:

```
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
```

Think:

> **ENTRYPOINT = how the process is launched**

> **CMD = what application/arguments are launched by default**

For example:

```
docker run image
```

→ `dumb-init -- node src/index.js`

If the CMD is changed:

```
docker run image node src/other.js
```

→ `dumb-init -- node src/other.js`

The `dumb-init` entrypoint remains.

---

# 10. `.dockerignore`

A Node.js service should generally exclude unnecessary files such as:

```
node_modules
.env
.env.*
.git
.gitignore
README.md
*.log
coverage/
tmp/
dist/
build/
.idea/
.vscode/
.DS_Store
```

Why?

`.dockerignore` prevents these files from being sent as part of the Docker build context.

Important:

> `.dockerignore` does not delete the files from Git. It only excludes them from the Docker build context.

---

# 11. Image-Level Security Practices

For the Docker image itself:

* Use a multi-stage build.
* Use a minimal runtime image.
* Run as a non-root user.
* Never bake secrets into the image.
* Use `.dockerignore`.
* Avoid unnecessary packages.
* Use production dependencies only.
* Clean package-manager caches.
* Prefer pinned base-image versions instead of `latest`.
* Keep application dependencies and base image versions maintained.

Runtime controls such as Kubernetes capabilities, seccomp, resource limits and read-only filesystems are handled separately at the container/Kubernetes runtime layer.

---

# 12. Interview Mental Model

When asked to design an optimized Node.js Docker image, think in this order:

```
1. Minimal Node base image
2. Multi-stage build
3. Set WORKDIR
4. Copy package.json/package-lock.json first
5. Install production dependencies
6. Clean npm cache
7. Start a clean runtime stage
8. Install only required runtime packages such as dumb-init
9. Copy required dependencies/application files
10. Create and use a non-root user
11. EXPOSE application port
12. Use dumb-init as PID 1
13. Use CMD for the default Node.js application command
```

### One-line interview answer

> **I would use a multi-stage Node.js Alpine build, copy package manifests first for layer caching, install only production dependencies, clean npm cache, use a minimal runtime image, run as a non-root user, use dumb-init as PID 1 for proper signal handling and graceful shutdown, and use ENTRYPOINT with CMD for predictable container startup.**
