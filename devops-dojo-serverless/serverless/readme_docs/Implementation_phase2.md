# Phase 2 – Event-Driven File Processing (S3 → Lambda)

## Objective

Build an event-driven workflow where a CSV file uploaded to Amazon S3 is processed by AWS Lambda. In this phase, the Lambda only downloads and parses the CSV. Database integration will be implemented in the next phase.

---

## Architecture

```text
User
   │
Upload CSV
   ▼
Backend API
   │
Upload File
   ▼
Amazon S3 (inbound/)
   │
ObjectCreated Event
   ▼
AWS Lambda
   │
Read S3 Object
   │
Parse CSV
   ▼
Python Objects (records)
```

---

## What We Built

* Created an S3 bucket with folder structure.
* Uploaded CSV files to the `inbound/` folder.
* Created an AWS Lambda function.
* Learned how S3 Events invoke Lambda.
* Extracted Bucket Name and Object Key from the S3 event.
* Downloaded the uploaded CSV using `boto3`.
* Parsed the CSV into Python objects using `csv.DictReader`.

---

## S3 Folder Structure

```text
bucket-name/
├── inbound/
├── processed/
└── error/
```

---

## Python Modules Used

```python
import boto3
import csv
from io import StringIO
```

---

## Lambda Functions Created

### Read S3 Object

```python
def read_s3_object(bucket, key):
```

**Purpose**

* Reads a file from Amazon S3.
* Converts bytes into a UTF-8 string.
* Returns the CSV content.

---

### Parse CSV

```python
def parse_csv(content):
```

**Purpose**

* Reads CSV content.
* Converts every row into a Python dictionary.
* Returns a list of records.

---

### Lambda Handler

```python
def lambda_handler(event, context):
```

**Responsibilities**

* Receive S3 Event.
* Extract Bucket Name.
* Extract Object Key.
* Read file from S3.
* Parse CSV.
* Print parsed records.

---

## S3 Event Fields Used

```python
bucket = event["Records"][0]["s3"]["bucket"]["name"]

key = event["Records"][0]["s3"]["object"]["key"]
```

Only these two attributes are required for this use case.

---

## Event Flow

```text
CSV Upload
      │
      ▼
S3 Event
      │
      ▼
Lambda
      │
Extract bucket & key
      │
Read file
      │
Parse CSV
      ▼
records[]
```

---

## Key Concepts Learned

### Event-Driven Architecture

* User uploads a file.
* Backend immediately responds with success.
* S3 publishes an event.
* Lambda processes the file in the background.
* User does not wait for database processing.

### Synchronous vs Asynchronous

**Synchronous**

* Caller waits for the response.
* Example: Login API.

**Asynchronous**

* Caller does not wait.
* Example: S3 triggering Lambda.

---

## Troubleshooting

### AccessDenied while reading S3 object

**Cause**

Lambda test event was using the default sample bucket (`example-bucket`).

**Fix**

Updated the Test Event with:

* Actual Bucket Name
* Actual Object Key

---

### boto3 Access from Lambda

Attached IAM permission:

* AmazonS3ReadOnlyAccess

This allowed Lambda to download objects from S3.

---

## Current Status

* ✅ Upload CSV to S3
* ✅ Lambda receives S3 Event
* ✅ Extract Bucket & Object Key
* ✅ Read CSV from S3
* ✅ Parse CSV into Python Objects

---

## Next Phase

* Create SQLAlchemy Model
* Generate Alembic Migration
* Create Transaction Table
* Insert Parsed Records into PostgreSQL
* Configure S3 Trigger to invoke Lambda automatically
