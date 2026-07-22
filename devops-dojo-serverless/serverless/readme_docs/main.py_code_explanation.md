# CODE_EXPLANATION.md

# Lambda CSV Processing - Code Explanation

## Overview

This Lambda function is responsible for processing a CSV file uploaded to Amazon S3.

Its responsibilities are:

- Read the uploaded CSV file from S3.
- Parse the CSV into Python objects.
- Create a transaction record.
- Insert all questions into PostgreSQL.
- Update the transaction status.
- Handle failures gracefully.

The complete execution flow is:

S3 Upload
↓
Lambda Trigger
↓
Read File
↓
Parse CSV
↓
Connect to Database
↓
Create Upload Transaction
↓
Insert Questions
↓
Update Transaction Status
↓
Commit Changes
↓
Return Success

---

# Import Statements

```python
import boto3
```

Used to communicate with AWS services.

In this project it is used only for Amazon S3.

---

```python
import csv
```

Python's built-in CSV library.

Used to read CSV files row by row.

Instead of manually splitting commas, this library automatically understands CSV headers and values.

---

```python
from io import StringIO
```

The CSV library expects a file-like object.

Since S3 returns the file content as a string, `StringIO` converts that string into an in-memory file so that `csv.DictReader()` can read it.

Without `StringIO`, `DictReader` cannot process the string directly.

---

```python
from db import get_db_connection
```

Imports the database connection function from `db.py`.

This separates database connection logic from business logic.

Instead of writing database connection code inside `main.py`, we simply call this reusable function.

---

```python
from datetime import datetime, UTC
```

Used while inserting records into PostgreSQL.

Stores the current timestamp in UTC timezone.

Using UTC avoids timezone-related issues across different regions.

---

# AWS Client

```python
s3 = boto3.client("s3")
```

Creates an S3 client object.

Every S3 operation like:

- Download file
- Read object
- Upload object

is performed using this object.

Instead of creating a new client every time, one client is created and reused throughout the program.

---

# Function : read_s3_object()

```python
def read_s3_object(bucket, key):
```

## Purpose

Reads a file from Amazon S3.

### Parameters

bucket

The bucket containing the uploaded file.

key

The complete path of the uploaded object.

Example

```
uploads/questions.csv
```

---

Inside the function

```python
response = s3.get_object(...)
```

Downloads the object from S3.

AWS returns a response object containing:

- Metadata
- Headers
- File Content

---

```python
content = response["Body"].read().decode("utf-8")
```

This is the actual file content.

Step by step:

Body

↓

Read bytes

↓

Decode bytes into UTF-8 string

↓

Return text

If the CSV contains

```
name,age
John,25
```

The function finally returns

```
name,age
John,25
```

as a Python string.

---

Return Value

```
String
```

containing the complete CSV content.

---

# Function : parse_csv()

```python
def parse_csv(content):
```

## Purpose

Converts raw CSV text into Python dictionaries.

This is called **Parsing**.

Instead of working with plain text, Python converts every row into a dictionary.

---

Inside

```python
csv.DictReader(StringIO(content))
```

`StringIO`

Converts the string into a file-like object.

`DictReader`

Reads the first row as headers.

Every remaining row becomes a dictionary.

Example

CSV

```
topic_slug,question_text
python,What is Lambda?
```

becomes

```python
{
    "topic_slug":"python",
    "question_text":"What is Lambda?"
}
```

---

```python
records = []
```

Creates an empty list.

This list will store every parsed row.

---

```python
for row in csv_reader:
```

Loops through every row.

Each row is already a dictionary.

---

```python
records.append(row)
```

Adds every dictionary into the list.

Finally,

```
records
```

looks like

```python
[
    {...},
    {...},
    {...}
]
```

---

Return Value

A list of dictionaries.

This list is later inserted into PostgreSQL.

---

# Function : create_upload_transaction()

Purpose

Creates one transaction record before processing starts.

Think of it like creating an audit log.

If processing fails later,

we still know

- Which file was uploaded
- Which bucket
- Current status

---

```python
file_name = key.split("/")[-1]
```

Extracts only the filename.

Example

```
uploads/questions.csv
```

becomes

```
questions.csv
```

---

The SQL query inserts

- filename
- bucket
- object key
- PROCESSING status

---

```python
RETURNING id
```

Immediately returns the generated primary key.

Example

```
Transaction ID = 105
```

This ID is used throughout the rest of the processing.

---

Return Value

Transaction ID.

---

# Function : insert_uploaded_questions()

Purpose

Insert every parsed CSV record into the database.

---

Input

- Database Connection
- Transaction ID
- Parsed Records

---

```python
for record in records
```

Loops through every parsed CSV row.

Each iteration inserts one database record.

---

```python
int(record["correct_answer"])
```

CSV stores everything as text.

Database expects integer.

So conversion is performed before insertion.

---

```python
datetime.now(UTC)
```

Stores current processing time.

---

# Function : update_upload_transaction()

Purpose

Updates the transaction created earlier.

Initially

```
PROCESSING
```

Later becomes

```
SUCCESS
```

or

```
FAILED
```

It also stores

- Total records
- Success count
- Failed count
- Validation error
- Processed timestamp

This provides complete tracking for every uploaded file.

---

# Function : lambda_handler()

This is the entry point of AWS Lambda.

AWS always starts execution from this function.

---

Input Parameters

```python
event
```

Contains S3 event details.

Example

Bucket Name

Object Key

Upload Details

---

```python
context
```

Contains Lambda runtime information.

In this project,

it is not used.

---

Execution Flow

### Step 1

Extract bucket name

```python
bucket = event["Records"][0]["s3"]["bucket"]["name"]
```

---

### Step 2

Extract object key

```python
key = event["Records"][0]["s3"]["object"]["key"]
```

---

### Step 3

Read uploaded CSV from S3.

Calls

```
read_s3_object()
```

---

### Step 4

Parse CSV.

Calls

```
parse_csv()
```

Returns list of dictionaries.

---

### Step 5

Connect to PostgreSQL.

Calls

```
get_db_connection()
```

---

### Step 6

Create upload transaction.

Calls

```
create_upload_transaction()
```

Status becomes

```
PROCESSING
```

---

### Step 7

Commit transaction.

Ensures transaction ID is permanently stored.

---

### Step 8

Insert all parsed questions.

Calls

```
insert_uploaded_questions()
```

---

### Step 9

Update transaction.

Changes status

```
PROCESSING

↓

SUCCESS
```

---

### Step 10

Commit again.

Makes all inserted records permanent.

---

### Step 11

Return

```json
{
    "statusCode":200,
    "body":"CSV processed successfully"
}
```

Lambda execution finishes successfully.

---

# Exception Handling

If any error occurs,

Execution immediately jumps into

```python
except Exception as e
```

Actions performed

- Rollback database changes
- Update transaction status to FAILED
- Store validation error
- Commit failure status
- Print error
- Raise exception again

This ensures partial data is never stored.

---

# Finally Block

```python
finally:
```

Always executes.

Whether success or failure,

the database connection is closed.

This prevents connection leaks.

---

# Complete Function Dependency

```
lambda_handler()

│

├── read_s3_object()

├── parse_csv()

├── get_db_connection()

├── create_upload_transaction()

├── insert_uploaded_questions()

└── update_upload_transaction()
```

The `lambda_handler()` acts as the **orchestrator**. It does not contain business logic itself; instead, it coordinates specialized functions, each with a single responsibility. This makes the code easier to read, test, and maintain.