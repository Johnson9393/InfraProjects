# Frontend Dockerfile Explained in Simple Terms

## Objective

The purpose of this Dockerfile is to:

1. Build the React application.
2. Convert React source code into static files.
3. Package the application into a Docker image.
4. Run the frontend using a lightweight Node.js server.

This Dockerfile uses a **Multi-Stage Build**, which is considered a Docker best practice for frontend applications.

---

# Complete Dockerfile

```dockerfile
# Build stage
FROM node:20-alpine as build

WORKDIR /app

COPY package*.json ./

RUN npm install
RUN npm install @tailwindcss/forms

COPY . .

RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install express http-proxy-middleware

COPY --from=build /app/build ./build

COPY server.js .

EXPOSE 80

ENV BACKEND_URL=http://backend.3-tier-app-eks.svc.cluster.local:8000

CMD ["node", "server.js"]
```

---

# What is a Multi-Stage Build?

Before understanding the Dockerfile, it is important to understand Multi-Stage Builds.

---

## Without Multi-Stage Build

```text
Docker Image
├── React Source Code
├── Node Modules
├── Build Tools
├── npm Cache
├── Build Artifacts
└── Runtime Files
```

Result:

```text
Large Image
Slower Deployment
More Security Risks
```

---

## With Multi-Stage Build

Stage 1:

```text
Build React Application
```

Stage 2:

```text
Run React Application
```

Only the required files are copied into the final image.

Result:

```text
Smaller Image
Faster Deployment
Better Security
Cleaner Design
```

---

# Why Multi-Stage Build is Important

Imagine building a house.

### During Construction

You need:

```text
Cement
Sand
Scaffolding
Tools
Workers
```

---

### After Construction

You only need:

```text
Finished House
```

You don't keep:

```text
Scaffolding
Construction Equipment
```

inside the house.

---

The same concept applies here.

Build tools are needed only during build time.

They are not needed at runtime.

---

# Stage 1 - Build Stage

---

## Base Image

```dockerfile
FROM node:20-alpine as build
```

### What it does

Downloads:

```text
Node.js 20
+
Alpine Linux
```

and names this stage:

```text
build
```

---

### Why Alpine?

Alpine is a very lightweight Linux distribution.

Benefits:

```text
Smaller Images
Faster Downloads
Less Storage
```

---

### Why "as build"?

Allows us to reference this stage later.

Example:

```dockerfile
COPY --from=build
```

---

# Set Working Directory

```dockerfile
WORKDIR /app
```

Equivalent:

```bash
mkdir /app
cd /app
```

All future commands execute inside:

```text
/app
```

---

# Copy Package Files

```dockerfile
COPY package*.json ./
```

Copies:

```text
package.json
package-lock.json
```

into container.

---

### Why Copy Package Files First?

Docker caching.

If only source code changes:

```text
App.js
Home.js
```

and dependencies remain the same,

Docker can reuse previous dependency installation.

This significantly reduces build time.

---

# Install Dependencies

```dockerfile
RUN npm install
```

Installs all frontend dependencies.

Examples:

```text
React
Axios
React Router
Tailwind CSS
```

---

# Install Tailwind Forms

```dockerfile
RUN npm install @tailwindcss/forms
```

Installs Tailwind Forms plugin.

Used for styling:

```text
Input Fields
Dropdowns
Forms
Buttons
```

---

# Copy Application Source Code

```dockerfile
COPY . .
```

Copies entire frontend application.

Examples:

```text
src/
public/
components/
pages/
App.js
```

---

# Build React Application

```dockerfile
RUN npm run build
```

This is the most important step.

---

## What Happens Here?

React source code:

```text
JSX
Components
Tailwind CSS
```

gets converted into:

```text
HTML
CSS
JavaScript
```

that browsers can understand.

---

### Before Build

```text
src/
├── App.js
├── Home.js
├── Quiz.js
```

---

### After Build

```text
build/
├── index.html
├── static/js
├── static/css
```

---

### Result

A production-ready React application.

---

# Stage 2 - Production Stage

Now we start a completely new image.

---

## Base Image

```dockerfile
FROM node:20-alpine
```

This creates a fresh image.

Notice:

```text
Source Code Not Copied
Node Build Dependencies Not Copied
npm Build Cache Not Copied
```

Only required files will be added.

---

# Working Directory

```dockerfile
WORKDIR /app
```

Creates:

```text
/app
```

inside container.

---

# Copy Package Files

```dockerfile
COPY package*.json ./
```

Copies package definitions.

---

# Install Runtime Dependencies

```dockerfile
RUN npm install express http-proxy-middleware
```

Only installs runtime dependencies.

---

## Express

Used as:

```text
Web Server
```

Responsibilities:

```text
Serve React Files
Handle Requests
```

---

## http-proxy-middleware

Used to forward API requests.

Example:

```text
Frontend Request
      ↓
Proxy
      ↓
Backend API
```

---

# Copy Build Artifacts

```dockerfile
COPY --from=build /app/build ./build
```

This is where Multi-Stage Build becomes useful.

---

### What Happens?

Take:

```text
Build Stage
/app/build
```

and copy it into:

```text
Production Stage
/app/build
```

---

### Result

Only production files are copied.

Source code remains behind.

---

# Copy Express Server

```dockerfile
COPY server.js .
```

Copies:

```text
server.js
```

into container.

---

### What is server.js?

Usually contains:

```text
Express Configuration
Static File Serving
API Proxy Configuration
```

It acts as the frontend web server.

---

# Expose Port

```dockerfile
EXPOSE 80
```

Documents that the application listens on:

```text
Port 80
```

inside container.

---

### Important

This does not publish the port.

It simply informs Docker and developers:

```text
Application Port = 80
```

---

# Backend URL Environment Variable

```dockerfile
ENV BACKEND_URL=http://backend.3-tier-app-eks.svc.cluster.local:8000
```

Creates environment variable:

```text
BACKEND_URL
```

Purpose:

```text
Frontend needs to know where Backend API is running.
```

---

### Important Note

This is only a default value.

In ECS, EKS, or other environments, this value is usually overridden.

Example:

```text
ECS Task Definition
```

may inject:

```text
BACKEND_URL=http://backend:8000
```

using ECS Service Connect.

---

### Why Environment Variables?

Without environment variables:

```text
Code Change Required
Rebuild Docker Image Required
```

for every environment.

With environment variables:

```text
Same Image
Different Environment Values
```

This follows:

```text
Build Once
Deploy Everywhere
```

which is a DevOps best practice.

---

# Start Frontend Server

```dockerfile
CMD ["node", "server.js"]
```

This command runs when the container starts.

Equivalent:

```bash
node server.js
```

---

## What Happens?

```text
Container Starts
       ↓
Node Starts
       ↓
Express Starts
       ↓
Port 80 Listening
       ↓
Serve React Application
```

---

# Build Flow

When Docker builds:

```text
1. Download Node Image
2. Create /app
3. Copy package.json
4. Install Dependencies
5. Copy Source Code
6. Build React Application
7. Create New Production Image
8. Install Runtime Dependencies
9. Copy Build Files
10. Copy server.js
11. Build Final Image
```

---

# Runtime Flow

When Container Starts:

```text
Container Starts
       │
       ▼
Node server.js
       │
       ▼
Express Server Starts
       │
       ▼
Port 80 Listening
       │
       ▼
Browser Loads React Application
       │
       ▼
Frontend Calls Backend API
       │
       ▼
Backend Processes Request
```

---

# Advantages of This Dockerfile

### Smaller Image Size

Only production files are included.

---

### Faster Deployment

Less data to push and pull.

---

### Better Security

Source code and build tools are not shipped.

---

### Easier Maintenance

Build and runtime concerns are separated.

---

### Reusable Across Environments

Same image can run in:

```text
Local Docker
ECS
EKS
DEV
UAT
PROD
```

by changing only environment variables.

---

# Interview Summary

If asked:

"What does your frontend Dockerfile do?"

You can answer:

> The frontend Dockerfile uses a multi-stage build. The first stage builds the React application using Node.js and converts the source code into production-ready static files. The second stage creates a lightweight runtime image, installs only the required runtime dependencies such as Express, copies the built assets from the build stage, configures the backend API endpoint through an environment variable, exposes port 80, and starts the application using a Node.js Express server. This approach reduces image size, improves security, and follows Docker best practices.
