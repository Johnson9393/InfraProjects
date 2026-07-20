# Phase 3 - Database Migrations using Alembic (Part 1)

---

                               PHASE 3 - SERVERLESS TRANSACTION PROCESSOR

                                   ┌────────────────────────────┐
                                   │        Frontend/API        │
                                   │  Upload Questions Endpoint │
                                   └──────────────┬─────────────┘
                                                  │
                                                  ▼
                                      Upload CSV to S3 Bucket
                                                  │
                                                  ▼
                                   ┌────────────────────────────┐
                                   │      Amazon S3 Bucket      │
                                   │ inbound/docker_questions.csv│
                                   └──────────────┬─────────────┘
                                                  │
                                           S3 Event Trigger
                                                  │
                                                  ▼
                              ┌──────────────────────────────────────┐
                              │         AWS Lambda Function          │
                              │     serverless-transaction-processor │
                              └──────────────────────────────────────┘
                                                  │
                                                  ▼
                                    Read Bucket & Object Key
                                                  │
                                                  ▼
                                      Download CSV from S3
                                                  │
                                                  ▼
                                  Parse CSV → Python Dictionaries
                                                  │
                                                  ▼
                               Open PostgreSQL Connection (psycopg)
                                                  │
                                                  ▼
                     ┌───────────────────────────────────────────────────┐
                     │               TRANSACTION - 1                     │
                     ├───────────────────────────────────────────────────┤
                     │ Insert upload_transactions                        │
                     │ Status = PROCESSING                               │
                     │ RETURNING transaction_id                          │
                     │ COMMIT                                            │
                     └───────────────────────────────────────────────────┘
                                                  │
                                                  ▼
                     ┌───────────────────────────────────────────────────┐
                     │               TRANSACTION - 2                     │
                     ├───────────────────────────────────────────────────┤
                     │ Loop through CSV Records                          │
                     │ Insert uploaded_questions                         │
                     │ (using transaction_id as Foreign Key)             │
                     └───────────────────────────────────────────────────┘
                                                  │
                              ┌───────────────────┴────────────────────┐
                              │                                        │
                              ▼                                        ▼
                     SUCCESS PATH                              FAILURE PATH
                              │                                        │
                              ▼                                        ▼
              Update upload_transactions              Rollback Question Inserts
              status = SUCCESS                        Update status = FAILED
              success_records = total                 validation_error = Exception
              failed_records = 0                      failed_records = total
              processed_at = CURRENT_TIMESTAMP        processed_at = CURRENT_TIMESTAMP
                              │                                        │
                              └───────────────────┬────────────────────┘
                                                  ▼
                                               COMMIT
                                                  │
                                                  ▼
                                   Close Database Connection
                                                  │
                                                  ▼
                                           Lambda Ends

---

## Objective

The objective of this phase is to prepare the database for storing uploaded CSV files by introducing a new database table using Alembic migrations.

Instead of creating tables directly from the Lambda function or backend logic, the database schema is managed using migrations, making deployments version-controlled, maintainable, and production-ready.

---

# Step 1 - Create UploadTransaction Model

## File Updated

```text
backend/app/models/models.py
```

## Model Added

```python
from datetime import datetime, UTC

class UploadTransaction(db.Model):
    __tablename__ = "upload_transactions"

    id = db.Column(db.Integer, primary_key=True)

    file_name = db.Column(db.String(255), nullable=False)

    bucket_name = db.Column(db.String(255), nullable=False)

    object_key = db.Column(db.String(500), nullable=False)

    status = db.Column(db.String(20), nullable=False, default="UPLOADED")

    total_records = db.Column(db.Integer, default=0)

    success_records = db.Column(db.Integer, default=0)

    failed_records = db.Column(db.Integer, default=0)

    validation_error = db.Column(db.Text)

    uploaded_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(UTC)
    )

    processed_at = db.Column(db.DateTime)
```

### Purpose

This table stores metadata about every uploaded CSV file.

Each uploaded file represents one transaction.

The actual CSV records will be stored in another table (`uploaded_questions`) later in this phase.

---

# Step 2 - Generate Alembic Migration

## Command Executed

```bash
docker compose exec backend flask db migrate -m "Add upload_transactions table"
```

## Result

Alembic detected the newly created SQLAlchemy model and generated a migration file.

Example output:

```text
Detected added table 'upload_transactions'

Generating migrations/versions/916a3c42ed8a_add_upload_transactions_table.py
```

No changes were made to the database at this stage.

Only the migration file was generated.

---

# Generated Migration File

## Location

```text
migrations/versions/
```

Generated file:

```text
916a3c42ed8a_add_upload_transactions_table.py
```

The migration contains two important functions.

### upgrade()

Responsible for moving the database schema to the next version.

Generated command:

```python
op.create_table(...)
```

This eventually translates into a SQL `CREATE TABLE` statement.

---

### downgrade()

Responsible for reverting the migration.

Generated command:

```python
op.drop_table("upload_transactions")
```

This allows the database to return to the previous version if required.

---

# Step 3 - Apply Migration

## Command Executed

```bash
docker compose exec backend flask db upgrade
```

## Result

The generated migration was executed successfully.

The `upload_transactions` table was created inside PostgreSQL.

---

# Step 4 - Verify Database Tables

Connected to PostgreSQL.

```bash
docker compose exec db psql -U postgres -d devops_learning
```

List all tables.

```sql
\dt
```

Output:

```text
public | alembic_version
public | questions
public | quiz_attempts
public | quiz_sessions
public | topics
public | upload_transactions
public | wiki_pages
```

Verification completed successfully.

The new table was available inside the database.

---

# Step 5 - Verify Alembic Version

Executed:

```sql
SELECT * FROM alembic_version;
```

Output:

```text
version_num
----------------
916a3c42ed8a
```

This confirms that the current database schema version matches the latest applied migration.

Alembic uses this version to determine which migrations have already been executed during future deployments.

---

# Flyway vs Alembic (Quick Comparison)

| Flyway                                          | Alembic                                                     |
| ----------------------------------------------- | ----------------------------------------------------------- |
| SQL-first approach                              | Model-first approach                                        |
| Developers write SQL migration scripts manually | SQLAlchemy models generate migration scripts automatically  |
| Executes SQL migrations                         | Generates Python migration scripts which are later executed |
| Maintains `flyway_schema_history`               | Maintains current schema version in `alembic_version`       |

---

# Commands Used

Generate migration

```bash
docker compose exec backend flask db migrate -m "Add upload_transactions table"
```

Apply migration

```bash
docker compose exec backend flask db upgrade
```

Connect to PostgreSQL

```bash
docker compose exec db psql -U postgres -d devops_learning
```

List all tables

```sql
\dt
```

Verify applied migration version

```sql
SELECT * FROM alembic_version;
```

---

# Verification Completed

* UploadTransaction model created.
* Alembic migration generated successfully.
* Migration applied successfully.
* Database table verified.
* Alembic version verified.
* Migration file reviewed and understood.

---

# Step 6 - Create UploadedQuestion Model

## Objective

Create a new database table to store every question parsed from the uploaded CSV file.

Instead of storing everything in a single table, the application follows a normalized database design.

### Enterprise Design

```text
One Upload Transaction
        │
        │ (One-to-Many)
        ▼
Many Uploaded Questions
```

Each uploaded CSV file creates one record in the `upload_transactions` table.

Each row inside the CSV creates one record in the `uploaded_questions` table.

---

## Model Added

```python
class UploadedQuestion(db.Model):
    __tablename__ = "uploaded_questions"

    id = db.Column(db.Integer, primary_key=True)

    transaction_id = db.Column(
        db.Integer,
        db.ForeignKey("upload_transactions.id"),
        nullable=False
    )

    topic_slug = db.Column(db.String(100), nullable=False)

    question_text = db.Column(db.Text, nullable=False)

    option1 = db.Column(db.Text, nullable=False)

    option2 = db.Column(db.Text, nullable=False)

    option3 = db.Column(db.Text, nullable=False)

    option4 = db.Column(db.Text, nullable=False)

    correct_answer = db.Column(db.Integer, nullable=False)

    created_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(UTC)
    )
```

---

# Database Design Decision

The project follows a fixed-schema approach.

The uploaded CSV file is expected to contain a predefined structure.

Expected columns:

```text
topic_slug
question_text
option1
option2
option3
option4
correct_answer
```

Any CSV uploaded with a different structure will later be rejected during validation.

---

# Primary Key Design

The `uploaded_questions` table uses an auto-generated primary key.

```text
id
```

instead of a composite primary key.

This simplifies:

* Future updates
* Future deletes
* Auditing
* ORM mapping
* Joins

This is the commonly followed approach in enterprise applications.

---

# Foreign Key Design

The `transaction_id` column references:

```text
upload_transactions.id
```

This creates a One-to-Many relationship.

Example:

```text
Upload Transaction

id = 10

↓

Uploaded Questions

id = 1

transaction_id = 10

--------------

id = 2

transaction_id = 10

--------------

id = 3

transaction_id = 10
```

One uploaded file can therefore own many uploaded questions.

---

# Relationship Added

Inside the `UploadTransaction` model:

```python
uploaded_questions = db.relationship(
    "UploadedQuestion",
    backref="transaction",
    lazy=True,
    cascade="all, delete-orphan"
)
```

The relationship is added only to improve object navigation inside SQLAlchemy.

Examples:

```python
transaction.uploaded_questions
```

or

```python
question.transaction
```

The relationship is an ORM feature.

It is not a database object.

---

# Generate Second Migration

## Command Executed

```bash
docker compose exec backend flask db migrate -m "Add uploaded_questions table"
```

Alembic output:

```text
Detected added table 'uploaded_questions'
Generating migrations/versions/bb3beb0f0ff7_add_uploaded_questions_table.py
```

---

# Review Generated Migration

The generated migration introduced a new table.

Important additions:

```python
sa.ForeignKeyConstraint(
    ['transaction_id'],
    ['upload_transactions.id']
)
```

This creates the actual Foreign Key constraint inside PostgreSQL.

The migration did **not** include:

```python
relationship(...)
```

This is expected because `relationship()` is only understood by SQLAlchemy.

The database only understands:

* Tables
* Columns
* Primary Keys
* Foreign Keys
* Constraints

---

# Apply Migration

Command executed:

```bash
docker compose exec backend flask db upgrade
```

Migration completed successfully.

---

# Verify Database

Connected to PostgreSQL.

```bash
docker compose exec db psql -U postgres -d devops_learning
```

Verify tables.

```sql
\dt
```

Output verified:

```text
upload_transactions

uploaded_questions

alembic_version
```

Both newly created tables were successfully available.

---

# Verify Alembic Version

Executed:

```sql
SELECT * FROM alembic_version;
```

Output:

```text
bb3beb0f0ff7
```

This confirms the database schema is now updated to the latest migration version.

---

# Architecture Decision

Initially, the Lambda implementation was planned to reuse the backend SQLAlchemy models.

After reviewing the project structure, the design was revised.

Final approach:

```text
Backend

↓

Owns Database Schema

↓

SQLAlchemy Models

↓

Alembic Migrations

========================

Lambda

↓

Read CSV

↓

Parse CSV

↓

Validate CSV

↓

Write Data

↓

Update Processing Status
```

Database ownership remains with the backend application.

Lambda only performs processing and writes data into the existing schema.

This avoids duplicating schema definitions across multiple applications and keeps responsibilities clearly separated.

---

# Phase 3 (Extension) – Lambda Database Integration

## Objective

Integrate the serverless transaction processor with PostgreSQL so that every uploaded CSV file is tracked and all parsed questions are stored against a single upload transaction.

---

# Architecture

```text
User Uploads CSV
        │
        ▼
       S3
        │
        ▼
   S3 Event Trigger
        │
        ▼
      Lambda
        │
        ├──────────────┐
        │              │
        ▼              ▼
Create Upload      Read CSV
Transaction         Parse CSV
        │              │
        └──────┬───────┘
               ▼
Insert Uploaded Questions
               │
               ▼
Commit Transaction
               │
               ▼
Close Database Connection
```

---

# Database Integration

Instead of using SQLAlchemy models inside Lambda, we decided to use **psycopg** with raw SQL.

Reason:

* Backend owns the database schema.
* Lambda only consumes the existing schema.
* Avoid duplicate ORM models.
* Lightweight and easier to maintain.

---

# db.py

Created a dedicated database module.

Responsibilities:

* Build PostgreSQL connection string.
* Read credentials from environment variables.
* Create database connection.
* Return connection object.

Environment Variables used:

```text
DB_USER
DB_PASSWORD
DB_HOST
DB_PORT
DB_NAME
```

---

# CSV Processing Flow

1. Receive S3 Event.
2. Extract Bucket Name.
3. Extract Object Key.
4. Download CSV from S3.
5. Parse CSV into Python dictionaries.
6. Open PostgreSQL connection.
7. Insert upload transaction.
8. Retrieve generated Transaction ID.
9. Insert every question using Transaction ID.
10. Commit transaction.
11. Close connection.

---

# SQL Implementation

Implemented raw parameterized SQL.

Example flow:

```text
INSERT upload_transactions
        │
RETURN transaction_id
        │
        ▼
Loop through CSV Records
        │
        ▼
INSERT uploaded_questions
```

Parameterized SQL was used to prevent SQL Injection.

---

# Transaction Design

Entire upload is treated as **one database transaction**.

```text
Open Connection
       │
       ▼
Insert Parent
       │
       ▼
Insert Child Records
       │
       ▼
Commit
```

If anything fails:

```text
Open Connection
       │
       ▼
Insert Parent
       │
       ▼
Failure
       │
       ▼
Rollback
       │
       ▼
Database Restored
```

This guarantees data consistency.

---

# Cursor Management

Instead of manually closing cursors:

```python
cursor = connection.cursor()
...
cursor.close()
```

Used:

```python
with connection.cursor() as cursor:
```

Benefits:

* Automatic cleanup.
* Safer during exceptions.
* Enterprise Python best practice.

---

# Exception Handling

Implemented:

```text
try
except
finally
```

Responsibilities:

**try**

* Execute complete business logic.

**except**

* Rollback database transaction.
* Log error.
* Re-raise exception.

**finally**

* Always close database connection.

---

# Enterprise Decisions

### Backend Responsibilities

* Database Models
* Alembic Migrations
* Schema Ownership

### Lambda Responsibilities

* Read S3 Event
* Read CSV
* Parse Data
* Execute Business Logic
* Insert Records
* Update Upload Status (next phase)

---

# Testing Performed

## Local Testing

* Installed psycopg dependency.
* Configured environment variables.
* Verified imports.
* Verified database connection.

## Lambda Simulation

Created:

```text
test_event.json
test.py
```

to simulate an S3 event locally.

Verified:

* Bucket extraction
* Object key extraction
* CSV parsing
* Database connection
* Parent insert
* Child inserts

---

# Database Verification

Verified using PostgreSQL.

```sql
SELECT * FROM upload_transactions;
```

Confirmed:

* Transaction ID generated.
* File metadata stored.
* Status = PROCESSING.

Verified:

```sql
SELECT COUNT(*) FROM uploaded_questions;
```

Result:

```text
51 Records Inserted
```

Successfully confirmed parent-child relationship using Transaction ID.

---

# Current Flow

```text
S3 Upload
      │
      ▼
Lambda Trigger
      │
      ▼
Read CSV
      │
      ▼
Parse CSV
      │
      ▼
Open DB Connection
      │
      ▼
Insert upload_transactions
      │
      ▼
Get transaction_id
      │
      ▼
Insert uploaded_questions
      │
      ▼
Commit Transaction
      │
      ▼
Close Connection
```

---

# Current Status

✅ Backend upload API completed.

✅ Database schema created using Alembic.

✅ Lambda integrated with PostgreSQL.

✅ CSV parsing completed.

✅ Parent-child relationship implemented.

✅ Parameterized SQL implemented.

✅ Transaction management implemented.

✅ Exception handling implemented.

✅ Local end-to-end testing completed.

## Next Phase

* Update upload status (`PROCESSING` → `SUCCESS` / `FAILED`)
* Populate processing statistics:

  * `total_records`
  * `success_records`
  * `failed_records`
  * `processed_at`
* Handle validation failures and record processing errors.


----



