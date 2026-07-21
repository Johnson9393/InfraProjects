# DevOps Dojo Serverless Enhancement - Phase 1

## Project Objective

Enhance the existing DevOps Dojo application by implementing an event-driven architecture without impacting the existing functionality.

Current Flow:

```text
CSV File
    │
Frontend
    │
Backend
    │
Amazon S3 (inbound/)
```

Future Flow:

```text
CSV File
    │
Frontend
    │
Backend
    │
Amazon S3 (inbound/)
    │
S3 Event Notification
    │
AWS Lambda
    │
Amazon RDS
```

---

# What We Achieved

* Added a new backend API for CSV upload.
* Existing APIs remain unchanged.
* Added CSV validation.
* Integrated backend with Amazon S3 using boto3.
* Successfully uploaded CSV files to the `inbound/` folder.
* Existing application continues to work without any impact.

---

# New API

```
POST /api/quiz/questions/upload-csv
```

### Responsibilities

* Accept multipart/form-data
* Validate CSV files
* Upload file to Amazon S3
* Return success response

---

# S3 Bucket Structure

```
devopsdojo-transaction-files-dev/

├── inbound/
├── archive/
└── error/
```

### Folder Purpose

| Folder   | Purpose                               |
| -------- | ------------------------------------- |
| inbound/ | Newly uploaded CSV files              |
| archive/ | Successfully processed files (Future) |
| error/   | Failed processing files (Future)      |

---

# Backend Changes

Modified:

```
backend/app/routes/quiz_routes.py
```

Added:

* New upload API
* CSV validation
* boto3 integration
* Upload to:

```
inbound/<filename>.csv
```

---

## 1. Backend Route

**File**

```text
backend/app/routes/quiz_routes.py
```

### Added boto3 import

```python
import boto3
```

---

### Created S3 Client

```python
s3_client = boto3.client("s3")

BUCKET_NAME = "devopsdojo-transaction-files-dev"
```

Purpose:

* Creates an Amazon S3 client.
* Reuses the same client throughout the application.

---

### Added New API

```python
@quiz_bp.route("/questions/upload-csv", methods=["POST"])
def upload_csv():

    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]

    if file.filename == "":
        return jsonify({"error": "Please select a CSV file"}), 400

    if not file.filename.lower().endswith(".csv"):
        return jsonify({"error": "Only CSV files are allowed"}), 400

    s3_client.upload_fileobj(
        file,
        BUCKET_NAME,
        f"inbound/{file.filename}"
    )

    return jsonify({
        "message": "CSV uploaded successfully to S3",
        "filename": file.filename
    }), 200
```

Purpose:

* Accepts multipart/form-data.
* Validates CSV files.
* Uploads the file to Amazon S3.
* Stores every uploaded file inside the `inbound/` folder.

---

## 2. Python Dependency

**File**

```text
backend/requirements.txt
```

Added:

```text
boto3
```

Purpose:

* Allows the backend to communicate with AWS services.

---

# Docker Changes

Mounted local AWS credentials into the backend container.

```yaml
volumes:
  - ./backend:/app
  - ~/.aws:/root/.aws
```

Purpose:

* Allows boto3 inside Docker to use local AWS credentials.
* Required for local development.

---

## 3. Docker Compose

**File**

```text
app/docker-compose.yml
```

Updated backend volumes:

```yaml
backend:
  build: ./backend
  volumes:
    - ./backend:/app
    - ~/.aws:/root/.aws
```

Purpose:

* Mounts the local AWS CLI configuration into the Docker container.
* Allows boto3 to use local AWS credentials during development.

---

# Commands Used

### Start Application

```bash
docker compose up --build
```

### Stop Application

```bash
docker compose down
```

### Backend Logs

```bash
docker compose logs backend
```

### Last 30 Backend Logs

```bash
docker compose logs backend --tail=30
```

### Verify AWS Credentials Inside Docker

```bash
docker compose exec backend ls /root/.aws
```

Expected:

```
config
credentials
sso
```

---

# Issues Faced & Fixes

## Issue 1

**Error**

```
ModuleNotFoundError: No module named 'boto3'
```

**Fix**

Added `boto3` to `requirements.txt` and rebuilt the Docker image.

---

## Issue 2

**Error**

```
NoCredentialsError: Unable to locate credentials
```

**Fix**

Mounted the local AWS credentials into the Docker container.

```yaml
~/.aws:/root/.aws
```

---

## Issue 3

**Error**

```
Read-only file system
```

**Cause**

Mounted AWS credentials as read-only (`:ro`) while using AWS SSO.

**Fix**

Changed:

```yaml
~/.aws:/root/.aws:ro
```

to

```yaml
~/.aws:/root/.aws
```

This allowed AWS SSO to refresh its token.

---

# Key Learnings

* Build enhancements without modifying existing features.
* Keep new functionality isolated.
* Use Amazon S3 as the entry point for event-driven workflows.
* Mount local AWS credentials for Docker-based development.
* Use dedicated folders (`inbound`, `archive`, `error`) for better file management.
* Validate uploads before sending them to S3.

---

# Development Workflow Followed

1. Created a new backend API.
2. Verified the API using Postman.
3. Added Amazon S3 integration.
4. Created an S3 bucket.
5. Created the folder structure:

   * inbound/
   * archive/
   * error/
6. Mounted local AWS credentials into Docker.
7. Uploaded a CSV file to S3.
8. Verified the uploaded file in the `inbound/` folder.

---

# Current Status

✅ Backend API created

✅ CSV validation implemented

✅ Docker integration completed

✅ Amazon S3 integration completed

✅ CSV successfully uploaded to `inbound/`

---

# Interview Talking Points

* Added a new feature without impacting the existing application.
* Integrated a Flask backend with Amazon S3 using boto3.
* Used Docker volume mounting for local AWS authentication.
* Followed an event-driven architecture approach.
* Designed the solution to be extensible with S3 Event Notifications and AWS Lambda.

---

# Next Phase

* Configure S3 Event Notification
* Create AWS Lambda function
* Trigger Lambda automatically on CSV upload
* Read CSV from S3
* Insert records into Amazon RDS
* Move processed files to `archive/`
* Move failed files to `error/`
---
