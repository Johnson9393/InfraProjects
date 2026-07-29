# Reflections – Phase 4 Design Decisions

## Introduction

While implementing the malware scanning worker, the biggest architectural decision was **how ClamAV should be started inside the Docker container**.

Initially, the scanner worked by starting ClamAV every time the application wanted to scan a file. Although this approach worked, it was inefficient and did not represent how a production malware scanning service should behave.

After analysing the workflow, we redesigned the application to follow the standard Linux daemon architecture.

Instead of treating ClamAV as a library that starts for every request, we now treat it as a long-running service that starts once when the container starts.

This design is much closer to how production workloads run on Amazon ECS or Kubernetes.

---

# Design Evolution

## Initial Design

```
Container Starts

↓

Python Worker Starts

↓

Receive File

↓

Start ClamAV

↓

Load Virus Database

↓

Scan File

↓

Exit ClamAV

↓

Wait for Next File
```

### Problems

- ClamAV startup is expensive.
- Virus database must be loaded every time.
- Increased scan latency.
- Wasted CPU cycles.
- Poor scalability.
- Not suitable for production containers.

---

## Improved Design

```
Container Starts

↓

entrypoint.sh

↓

Download Virus Database (only once)

↓

Start ClamAV Daemon

↓

Wait until daemon is ready

↓

Start Python Worker

↓

Receive Files

↓

Reuse Existing ClamAV Process

↓

Scan Files Continuously
```

---

# Why This Design?

The scanner container has two independent responsibilities.

## Responsibility 1

Run ClamAV continuously.

This process is responsible for:

- Loading virus signatures.
- Keeping the virus database in memory.
- Listening on a Unix socket.
- Waiting for scan requests.

---

## Responsibility 2

Run the Python application.

The Python application is responsible for:

- Polling Amazon SQS.
- Downloading files from Amazon S3.
- Sending scan requests to ClamAV.
- Deleting processed SQS messages.

Notice that the Python application never starts ClamAV.

It simply connects to an already running daemon.

This separation of responsibilities results in a much cleaner architecture.

---

# Final Container Architecture

```
                    Docker Container
+--------------------------------------------------+

            entrypoint.sh
                  │
                  ▼
         Download Virus Database
                  │
                  ▼
          Start ClamAV Daemon
                  │
                  ▼
        Wait Until Socket Exists
                  │
                  ▼
         Start Python Application
                  │
                  ▼
       Receive SQS Messages Forever
                  │
                  ▼
         Download File From S3
                  │
                  ▼
     Send Scan Request To ClamAV
                  │
                  ▼
          Receive Scan Result

+--------------------------------------------------+
```

---

# Why Use entrypoint.sh?

Docker allows only one command to start the container.

Instead of placing all startup logic inside Python, we moved container initialization into an entrypoint script.

This keeps responsibilities separated.

**entrypoint.sh**

- prepares the environment
- starts system services
- waits until dependencies are ready

**app.py**

- contains only business logic

This separation makes the application easier to maintain.

---

# Understanding entrypoint.sh

## Step 1

```
set -e
```

### Why?

If any command fails, the script immediately exits.

Without this option, the script may continue running even though a critical step failed.

Example

If Freshclam fails,

there is no reason to continue starting Python.

The container should fail immediately.

---

## Step 2

```
echo "Starting File Scanner Container..."
```

Purely for readability.

Provides a clean startup banner in container logs.

---

## Step 3

```
mkdir -p /var/run/clamav

mkdir -p /var/log/clamav
```

Creates runtime directories required by ClamAV.

`-p` ensures no error occurs if the directory already exists.

---

## Step 4

```
chown -R clamav:clamav ...
```

Changes ownership.

ClamAV does not run as the root user.

It requires permission to

- create sockets
- write log files
- access virus databases

Without these permissions,

ClamAV would fail during startup.

---

## Step 5

```
if [ ! -f /var/lib/clamav/main.cvd ]
```

Checks whether the main virus database already exists.

If the file is missing,

Freshclam downloads

- main.cvd
- daily.cvd
- bytecode.cvd

This avoids downloading signatures every time the container starts.

---

## Step 6

```
freshclam
```

Downloads the latest virus definitions.

Freshclam updates the local database from the official ClamAV servers.

The scanner becomes effective only after these signatures are available.

---

## Step 7

```
clamd --foreground >/dev/null 2>&1 &
```

This is the most important command.

Let's understand every part.

### clamd

Starts the ClamAV daemon.

---

### --foreground

Normally Linux daemons detach themselves from the terminal.

Inside Docker,

the main process should remain attached.

Running in foreground mode is the Docker-recommended approach.

---

### >/dev/null

Redirects standard output.

Removes unnecessary ClamAV startup logs from the terminal.

---

### 2>&1

Redirects standard error to the same location.

Keeps logs clean.

---

### &

Runs the process in the background.

This allows the shell script to continue executing.

Without this,

the script would stop here forever,

and Python would never start.

---

# Why Wait for the Socket?

```
while [ ! -S /var/run/clamav/clamd.ctl ]
do
    sleep 1
done
```

ClamAV needs a few seconds to finish startup.

During this time,

the socket does not exist.

If Python starts immediately,

it will attempt to connect before ClamAV is ready.

This results in connection errors.

The loop waits until the Unix socket is available.

Only then does the application continue.

---

# Starting the Python Worker

```
exec python -u app.py
```

### Why exec?

`exec` replaces the shell process with the Python process.

Benefits

- Proper signal handling.
- Cleaner process tree.
- Better container shutdown behaviour.

---

### Why -u?

Runs Python in unbuffered mode.

Without this option,

container logs may appear several seconds late.

Using `-u` prints logs immediately.

This makes debugging much easier.

---

# New Functions Introduced

## create_sqs_client()

Creates the SQS client once.

The same client is reused throughout the application.

---

## receive_messages()

Uses Amazon SQS long polling.

```
WaitTimeSeconds = 20
```

Advantages

- fewer API requests
- lower AWS cost
- reduced empty responses
- improved efficiency

---

## delete_message()

Deletes successfully processed messages.

Prevents duplicate processing.

---

## create_s3_client()

Creates the S3 client.

Like the SQS client,

it is created only once.

---

## download_file()

Downloads the S3 object into

```
/tmp/scanner
```

Using `/tmp` is ideal because containers have temporary local storage.

---

## scan_file()

Creates a Unix socket connection to ClamAV.

```
ClamdUnixSocket()
```

No new ClamAV process is started.

Instead,

the application communicates with the already running daemon.

This is significantly faster than starting ClamAV for every scan.

---

# Main Function Changes

The main function was extended into a continuous worker.

Workflow

```
Start Application

↓

Create Clients

↓

Infinite Loop

↓

Receive Message

↓

Ignore Test Event

↓

Download File

↓

Scan File

↓

Delete Message

↓

Repeat Forever
```

Unlike a traditional script,

this application never exits.

It continuously waits for new work.

This is exactly how workers operate inside Amazon ECS services.

---

# Architectural Benefits

This redesign provides several important advantages.

### Faster Scanning

Virus signatures are loaded only once.

Every scan reuses the existing ClamAV process.

---

### Lower CPU Usage

No repeated daemon startup.

No repeated database loading.

---

### Lower Memory Overhead

Only one ClamAV instance exists.

All scans share the same daemon.

---

### Better Separation of Responsibilities

entrypoint.sh

- infrastructure startup
- daemon initialization

app.py

- business logic
- AWS integration
- scanning workflow

---

### Production Ready

This architecture closely matches how malware scanning services are deployed in production using:

- Amazon ECS
- Docker
- Kubernetes

The worker can continue processing thousands of files without restarting the ClamAV service.

---

# Key Takeaways

At the end of Phase 4, the scanner follows a clean production-oriented design.

- ClamAV starts only once during container startup.
- Virus signatures are downloaded only when required.
- Python never starts or manages ClamAV directly.
- The worker communicates with ClamAV over a Unix socket.
- The container continuously polls Amazon SQS for new files.
- Each uploaded file is downloaded, scanned, and processed without restarting the application.
- This architecture is scalable, efficient, and suitable for deployment on Amazon ECS Fargate.