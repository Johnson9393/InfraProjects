# Phase 4 - Frontend Integration & End-to-End Local Validation

## Objective

The objective of this phase was to integrate the React frontend with the backend upload API and validate the complete end-to-end transaction processing workflow locally before deploying it to AWS.

---

# Architecture

```text
                   Browser
                      │
                      ▼
         Transactions (React UI)
                      │
                      ▼
POST /api/quiz/questions/upload-csv
                      │
                      ▼
               Flask Backend
                      │
          boto3.upload_fileobj()
                      │
                      ▼
                 Amazon S3
                      │
          (Local Lambda Test)
                      │
                      ▼
                  Lambda
                 (test.py)
                      │
          Read CSV & Parse Records
                      │
                      ▼
            PostgreSQL Database
        upload_transactions
        uploaded_questions
```

---

# Frontend Implementation

## New Component

Created

```text
frontend/src/components/UploadQuestions.js
```

Responsibilities

- Select Transaction CSV
- Upload CSV
- Display Success/Failure Message

---

## API Service

Created

```text
frontend/src/services/uploadService.js
```

Purpose

- Handle backend API communication
- Upload CSV using multipart/form-data

API Used

```http
POST /api/quiz/questions/upload-csv
```

---

## Navigation

Added new menu

```
Transactions
```

Added new route

```
/upload-questions
```

---

# Backend Flow

```
React UI
      │
      ▼
Upload CSV API
      │
      ▼
Validate Request
      │
      ▼
Upload File to S3
      │
      ▼
Return Success Response
```

---

# Docker Validation

Rebuilt application

```bash
docker compose down

docker compose up --build -d
```

---

# Testing Performed

## 1. Frontend Validation

Verified

- Transactions page loaded successfully.
- CSV selection worked.
- Upload button triggered backend API.

---

## 2. Backend Validation

Verified

- Backend received multipart request.
- Backend uploaded CSV successfully to S3.

---

## 3. AWS S3 Validation

Verified uploaded file inside

```
devopsdojo-transaction-files-dev

└── inbound/
```

---

## 4. Lambda Validation

Executed locally

```bash
cd serverless/transaction-processor

python test.py
```

Verified

- Read S3 Event
- Read CSV
- Parsed CSV
- Inserted Transaction
- Inserted Questions
- Updated Transaction Status

---

## 5. Database Validation

Connect Database

```bash
docker exec -it app-db-1 psql -U postgres -d devops_learning
```

Disable pager

```sql
\pset pager off
```

Latest Transaction

```sql
SELECT *
FROM upload_transactions
ORDER BY id DESC
LIMIT 1;
```

Latest Transaction ID

```sql
SELECT id
FROM upload_transactions
ORDER BY id DESC
LIMIT 1;
```

Verify inserted records

```sql
SELECT COUNT(*)
FROM uploaded_questions
WHERE transaction_id = <latest_transaction_id>;
```

View uploaded questions

```sql
SELECT *
FROM uploaded_questions
WHERE transaction_id = <latest_transaction_id>
LIMIT 5;
```

Transaction history

```sql
SELECT
    id,
    file_name,
    status,
    total_records,
    success_records,
    failed_records,
    processed_at
FROM upload_transactions
ORDER BY id DESC;
```

---

# Issues Faced & Troubleshooting

## Issue 1

### React Build Failed

```
Attempted import error:
API_BASE_URL is not exported
```

### Resolution

Updated `uploadService.js` to use the existing exported `API_URL`.

---

## Issue 2

### Upload API returned 500 Internal Server Error

### Root Cause

AWS SSO credentials expired inside Docker container.

Error

```
TokenRetrievalError

Token has expired
```

### Resolution

Refresh AWS credentials

```bash
aws sso login
```

Restart backend

```bash
docker compose restart backend
```

Upload worked successfully afterwards.

---

# End-to-End Validation

Successfully validated

```
React Frontend

↓

Backend Upload API

↓

Amazon S3

↓

Lambda (test.py)

↓

Parse CSV

↓

Insert upload_transactions

↓

Insert uploaded_questions

↓

Update Transaction Status

↓

PostgreSQL
```

---

# Outcome

- ✅ Frontend integrated with backend
- ✅ CSV upload from UI completed
- ✅ Backend uploaded file to Amazon S3
- ✅ Lambda processed uploaded CSV
- ✅ PostgreSQL updated successfully
- ✅ Transaction status updated successfully
- ✅ End-to-End local workflow validated

---

# Key Learnings

- React frontend can upload multipart files directly to Flask backend.
- Backend uploads files to S3 using boto3.
- Docker containers can reuse local AWS credentials through mounted `~/.aws`.
- Expired AWS SSO credentials can prevent S3 uploads.
- Transaction history is preserved by creating a new transaction for every upload.
- Complete workflow was validated locally before deploying to AWS.

---

# Next Phase

## Phase 5 - AWS Deployment

- Commit all frontend, backend and Lambda changes.
- Push code to GitHub.
- Trigger GitHub Actions pipeline.
- Run database migrations.
- Deploy updated ECS services.
- Configure S3 Event Notification.
- Trigger actual AWS Lambda automatically.
- Validate complete cloud-native architecture.