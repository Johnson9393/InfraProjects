# Phase 3 – Failure Handling, Transaction Design & Validation

## Objective

Validate that the Serverless Transaction Processor correctly handles failures during CSV processing while maintaining database consistency and preserving an audit trail for every upload attempt.

---

# Architecture

```text
                 Upload CSV
                      │
                      ▼
               Backend Upload API
                      │
                      ▼
                 Amazon S3 Bucket
                      │
               S3 Event Trigger
                      │
                      ▼
                  AWS Lambda
                      │
                      ▼
            Read Bucket & Object Key
                      │
                      ▼
             Download CSV from S3
                      │
                      ▼
        Parse CSV into Python Dictionaries
                      │
                      ▼
        Open PostgreSQL Connection (psycopg)
                      │
                      ▼
         ┌──────────────────────────────┐
         │      Transaction - 1         │
         ├──────────────────────────────┤
         │ Insert upload_transactions   │
         │ Status = PROCESSING          │
         │ RETURNING transaction_id     │
         │ COMMIT                       │
         └──────────────────────────────┘
                      │
                      ▼
         ┌──────────────────────────────┐
         │      Transaction - 2         │
         ├──────────────────────────────┤
         │ Insert uploaded_questions    │
         │ Update Status = SUCCESS      │
         │ COMMIT                       │
         └──────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
      Success                 Exception
          │                       │
          ▼                       ▼
       COMMIT              ROLLBACK
                                │
                                ▼
                  Update upload_transactions
                      Status = FAILED
                      Validation Error
                      Failed Records
                      Processed Time
                                │
                                ▼
                              COMMIT
```

---

# Why We Changed the Design

## Initial Design

Initially, everything was executed inside a single database transaction.

```text
Insert Parent
      │
Insert Children
      │
Failure
      │
ROLLBACK
```

Problem:

Rollback removed **both**:

* upload_transactions
* uploaded_questions

No audit information remained.

---

## Improved Enterprise Design

We separated the workflow into two transactions.

### Transaction 1

Purpose:

Persist the upload request.

```text
Insert upload_transactions

↓

COMMIT
```

Now the upload always exists in the database.

---

### Transaction 2

Purpose:

Process the uploaded CSV.

```text
Insert uploaded_questions

↓

SUCCESS

↓

Update upload_transactions

↓

COMMIT
```

If anything fails:

```text
Insert uploaded_questions

↓

Exception

↓

ROLLBACK

↓

Update upload_transactions

Status = FAILED

↓

COMMIT
```

This preserves the upload history while still keeping uploaded questions atomic.

---

# Code Changes

## 1. create_upload_transaction()

Created the upload record.

Returns

```python
transaction_id
```

Immediately committed.

```python
transaction_id = create_upload_transaction(...)

connection.commit()
```

Reason:

The upload request itself should never disappear.

---

## 2. insert_uploaded_questions()

Responsible only for inserting question records.

Uses

```python
with connection.cursor() as cursor:
```

Benefits

* Automatic cursor cleanup
* Cleaner code
* Enterprise Python pattern

---

## 3. update_upload_transaction()

Created a reusable function.

Responsibilities

* Update SUCCESS
* Update FAILED
* Store validation error
* Store processed timestamp
* Store statistics

SQL

```sql
UPDATE upload_transactions
SET
    status = %s,
    total_records = %s,
    success_records = %s,
    failed_records = %s,
    validation_error = %s,
    processed_at = CURRENT_TIMESTAMP
WHERE id = %s;
```

---

## 4. lambda_handler()

Implemented

```python
try
except
finally
```

### try

Business Logic

* Read S3
* Parse CSV
* Create Upload Transaction
* Commit
* Insert Questions
* Update SUCCESS
* Commit

---

### except

Business Logic

```text
Rollback Question Inserts

↓

Update FAILED Status

↓

Commit
```

Stored

* validation_error
* failed_records
* processed_at

---

### finally

Always executes

```python
connection.close()
```

Ensures database connections are never leaked.

---

# Failure Test Performed

Created

```text
docker_questions_invalid.csv
```

Modified

```text
correct_answer

0

↓

ABC
```

Reason

The application converts

```python
int(record["correct_answer"])
```

Therefore

```python
int("ABC")
```

throws

```text
ValueError
```

This forces the Lambda into the exception block.

---

# Commands Used

## Upload Invalid CSV

Used existing Backend Upload API through Insomnia.

Flow

```text
Insomnia

↓

Backend Upload API

↓

S3 Bucket
```

---

## Execute Lambda

```bash
python test.py
```

---

# Error Observed

```text
ValueError:

invalid literal for int() with base 10: 'ABC'
```

Expected behaviour.

---

# Database Verification

## Verify Upload Transaction

```sql
SELECT *
FROM upload_transactions
ORDER BY id DESC
LIMIT 1;
```

Observed

```text
Status = FAILED

Total Records = 51

Success Records = 0

Failed Records = 51

Validation Error = invalid literal for int() with base 10: 'ABC'

Processed Time = Present
```

---

## Verify Rollback

```sql
SELECT COUNT(*)
FROM uploaded_questions
WHERE transaction_id = 2;
```

Result

```text
0
```

Confirms rollback worked correctly.

---

# Final Enterprise Flow

```text
CSV Upload
      │
      ▼
Backend Upload API
      │
      ▼
Amazon S3
      │
      ▼
Lambda Trigger
      │
      ▼
Read CSV
      │
      ▼
Create Upload Transaction
      │
   COMMIT
      │
      ▼
Insert Questions
      │
      ├──────────────┐
      │              │
      ▼              ▼
Success          Failure
      │              │
      ▼              ▼
Update SUCCESS   ROLLBACK
      │              │
      │              ▼
      │      Update FAILED
      │              │
      └───────┬──────┘
              ▼
            COMMIT
              │
              ▼
     Close Database Connection
```

---

# Design Principles Learned

* Parent transaction should always exist.
* Child records must remain atomic.
* Use parameterized SQL to prevent SQL Injection.
* Separate business transactions from audit transactions.
* Rollback only business data.
* Preserve upload history.
* Store validation errors in the database.
* Always close database resources.
* Use context managers (`with`) for cursor management.
* Keep Lambda lightweight and let the backend own the database schema.

---

# Outcome

Successfully implemented and validated an enterprise-grade serverless transaction processing workflow with:

* Reliable audit trail
* Atomic database operations
* Proper rollback strategy
* Production-style error handling
* Upload status tracking (PROCESSING, SUCCESS, FAILED)
* End-to-end validation of both success and failure scenarios
