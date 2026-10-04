# Dockerfile — Build Stage & Runtime Stage

## 1. Dockerfile Structure

Our Product Service Dockerfile uses a **multi-stage build**:

* **Build stage** → contains Go compiler and build tools; compiles the application.
* **Runtime stage** → contains only what is required to run the compiled application.

Main idea:

Build environment → Compile → Copy binary → Minimal runtime image → Run application

---

## 2. Build Stage

### `FROM golang:1.21-alpine AS builder`

Uses Alpine Linux with Go 1.21.

* `golang:1.21-alpine` → relatively small image containing Go + Alpine.
* `AS builder` → gives this stage the name `builder`.
* This stage is used only for compiling the application.

---

### `WORKDIR /app`

Sets `/app` as the working directory inside the image.

All following commands operate from `/app`.

It keeps the application/build files organized in one location.

---

### `RUN apk add --no-cache git`

Installs Git inside the build image.

* `apk` → Alpine Linux package manager.
* `add` → install a package.
* `git` → package being installed.
* `--no-cache` → don't retain Alpine's package index/cache.

Important:

`--no-cache` does **not** remove Git.

Git remains installed; only the package-manager cache/index is not retained.

Why Git?

Some Go dependencies may need to be fetched from Git repositories.

---

### `COPY go.mod go.sum ./`

Copies Go dependency files into `/app`.

* `go.mod` → defines the module, Go version and dependencies.
* `go.sum` → contains dependency checksums used for integrity verification.
* `./` → current working directory, which is `/app`.

Copying these separately also improves Docker build caching.

---

### `RUN go mod download`

Downloads the Go dependencies declared in `go.mod`.

The dependencies are placed into Go's module cache so they are available during compilation.

Concept:

Dependency definitions → Download dependencies → Ready for build

---

### `COPY . .`

Copies the application source code from the Docker build context into `/app`.

At this point the Docker image has:

* Go environment
* Dependencies
* Application source code

---

### `RUN go mod tidy`

Synchronizes the Go dependency files with the actual source code.

It can:

* Remove unused dependencies.
* Add missing dependencies.
* Update `go.sum` as required.

Important distinction:

* `go mod download` → downloads dependencies.
* `go mod tidy` → cleans/synchronizes dependency definitions.

---

### `RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o main .`

Compiles the Go source code into an executable binary called `main`.

Key parts:

* `CGO_ENABLED=0` → build without CGO; produces a pure-Go binary.
* `GOOS=linux` → build a Linux executable.
* `go build` → compile the application.
* `-a` → force rebuilding of packages instead of relying on previous compiled cache.
* `-installsuffix cgo` → legacy option associated with distinguishing CGO builds; largely unnecessary with modern Go.
* `-ldflags="-w -s"` → remove debugging/symbol information to reduce binary size.
* `-o main` → name the resulting executable `main`.
* `.` → build the Go package in the current directory (`/app`).

Result:

`Go source code → /app/main`

---

# 3. Runtime Stage

The build stage is not used to run the application.

A new smaller image is created:

`FROM alpine:latest`

This keeps the final image much smaller because it doesn't contain:

* Go compiler
* Go source code
* Go module cache
* Build tools

Only the compiled application and required runtime components are copied.

---

### `RUN apk --no-cache add ca-certificates wget`

Installs runtime utilities:

* `ca-certificates` → allows HTTPS/TLS certificate verification.
* `wget` → useful for HTTP checks/debugging.

Again, `--no-cache` prevents Alpine package-manager cache from being retained.

---

### `RUN addgroup -g 1001 -S appuser && adduser -S appuser -u 1001`

Creates a dedicated non-root user.

* `addgroup` → creates a group.
* `-g 1001` → assigns GID 1001.
* `adduser` → creates a user.
* `-u 1001` → assigns UID 1001.
* `-S` → creates a system user/group.

`1001` is **not special**.

Another unused UID/GID such as `1000`, `2000`, etc. could be used.

The important point is having a dedicated non-root identity.

---

### `WORKDIR /app`

Sets `/app` as the working directory in the runtime image.

---

### `COPY --from=builder /app/main .`

Copies only the compiled binary from the build stage.

Source:

`builder:/app/main`

Destination:

`runtime:/app/main`

This is the key benefit of multi-stage builds.

We don't copy the entire build environment — only the final executable.

---

### `RUN chown -R appuser:appuser /app`

Changes ownership of `/app` to the non-root user.

This allows `appuser` to access the application files.

---

### `USER appuser`

Tells Docker to run the application as `appuser` instead of `root`.

This follows the principle of least privilege and improves container security.

---

### `EXPOSE 8001`

Documents that the application uses port `8001`.

Important:

`EXPOSE` does **not** publish the port to the host.

Port publishing requires something like:

`docker run -p 8001:8001 image`

---

### `CMD ["./main"]`

Defines the default command used to start the application.

When the container starts:

`./main`

is executed.

`CMD` can be easily replaced at runtime.

Example concept:

`docker run image /bin/sh`

Now `/bin/sh` replaces the CMD.

---

# 4. CMD vs ENTRYPOINT

### CMD

`CMD` = default command or default arguments.

It can be replaced simply by supplying another command when starting the container.

### ENTRYPOINT

`ENTRYPOINT` = main executable of the container.

Example:

`ENTRYPOINT ["./main"]`

Runtime arguments are normally appended:

`docker run image --port=9000`

Results in:

`./main --port=9000`

### Can ENTRYPOINT be overridden?

Yes.

Use Docker's explicit `--entrypoint` option:

`docker run --entrypoint /bin/sh image`

Now `/bin/sh` replaces the original ENTRYPOINT.

Therefore, saying "ENTRYPOINT cannot be overridden" is not technically correct.

Better statement:

**CMD is easily replaced; ENTRYPOINT is the default/fixed executable unless explicitly overridden with `--entrypoint`.**

### Common combination

`ENTRYPOINT ["./main"]`

`CMD ["--port=8001"]`

Then:

`docker run image`

runs:

`./main --port=8001`

But:

`docker run image --port=9000`

runs:

`./main --port=9000`

Simple mental model:

**ENTRYPOINT = what runs**

**CMD = default arguments**

---

# 5. Why Multi-Stage Build?

Without multi-stage builds, the final image could contain:

* Go compiler
* Git
* Source code
* Dependencies
* Build tools
* Application binary

With multi-stage builds:

Build stage:

`Source + Go + tools → Binary`

Runtime stage:

`Minimal Alpine + Binary → Running application`

Benefits:

* Smaller image.
* Smaller attack surface.
* Fewer unnecessary packages.
* No compiler/build tools in production runtime.
* Cleaner production container.

---

# 6. Complete Mental Model

Build stage:

`golang:1.21-alpine`

→ Set `/app`

→ Install Git

→ Copy `go.mod` + `go.sum`

→ Download dependencies

→ Copy source code

→ Tidy dependencies

→ Compile Linux binary

→ `/app/main`

Runtime stage:

`alpine`

→ Install required runtime packages

→ Create non-root user

→ Copy `/app/main`

→ Give ownership to `appuser`

→ Switch to `appuser`

→ Expose/document port 8001

→ Start `./main`

Final result:

**Small runtime image containing mainly the application binary and required runtime components.**

---

# 7. Key Interview Points

* Multi-stage builds separate **build environment** from **runtime environment**.
* `go.mod` defines Go dependencies; `go.sum` verifies dependency integrity.
* `go mod download` downloads dependencies.
* `go mod tidy` synchronizes and cleans dependency definitions.
* `CGO_ENABLED=0` creates a pure-Go binary.
* `GOOS=linux` creates a Linux executable.
* `-ldflags="-w -s"` reduces binary size by stripping debugging/symbol information.
* `USER appuser` prevents the application from running as root.
* `EXPOSE` documents a port; it does not publish it.
* `CMD` is a replaceable default command.
* `ENTRYPOINT` defines the default/main executable and can be explicitly overridden.
* `--no-cache` prevents Alpine package-manager cache/index from being retained; it does not remove installed packages.
