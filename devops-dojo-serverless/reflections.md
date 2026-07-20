# Reflections – Backend, Database & Event-Driven Architecture

This document captures the concepts I understood while building this project. It is not a step-by-step implementation guide. Instead, it explains **why** modern backend systems are designed the way they are.

---

# 1. Event-Driven Architecture

Traditional applications usually perform every operation in a single request.

```text
User
   │
Upload File
   │
Backend
   │
Write to Database
   │
Return Response
```

The user has to wait until every backend operation completes.

In an event-driven architecture, the responsibility is divided.

```text
User
   │
Upload File
   │
Backend
   │
Upload to S3
   │
Return Success Immediately
   │
S3 Event
   │
Lambda
   │
Process File
   │
Database
```

The user only waits for the file upload.

Everything else happens in the background.

This improves:

* User Experience
* Scalability
* Reliability
* Loose Coupling

---

# 2. Why S3 instead of writing directly to the Database?

S3 acts as a durable staging area.

Advantages:

* File is safely stored.
* Processing can happen later.
* Failed processing can be retried.
* Multiple services can consume the same file.
* Backend remains lightweight.

The backend's responsibility is only to receive the file and store it.

The backend should not perform long-running processing.

---

# 3. Lambda Responsibility

Lambda should only perform business processing.

Responsibilities:

* Read file from S3
* Validate the file
* Parse the CSV
* Write records into the database
* Move processed files
* Handle failures

Lambda should **not** create database tables.

---

# 4. Why Database Migrations?

Database schema management should not be mixed with application logic.

Application responsibilities:

* APIs
* Business Logic
* Validation
* Reading and Writing data

Migration responsibilities:

* Create tables
* Modify tables
* Add columns
* Remove columns
* Version database changes

Keeping these responsibilities separate makes deployments much safer.

---

# 5. Alembic vs Flyway

Both solve the same problem:

Database Version Management.

Flyway:

* SQL First
* Developers write SQL migration scripts manually.

Alembic:

* Model First
* Developers create SQLAlchemy models.
* Alembic compares models with the database.
* Generates migration scripts automatically.

Migration generation and migration execution are two different steps.

```text
Model
   │
flask db migrate
   │
Migration File
   │
flask db upgrade
   │
Database Updated
```

---

# 6. What is a Database Schema?

A schema defines the structure of the database.

It includes:

* Tables
* Columns
* Data Types
* Constraints
* Relationships
* Indexes

The schema represents the blueprint of the database.

---

# 7. Transactional DDL

DDL stands for Data Definition Language.

Examples:

* CREATE TABLE
* ALTER TABLE
* DROP TABLE

PostgreSQL executes schema changes inside a transaction.

If one operation fails:

```text
ROLLBACK
```

The database returns to its previous state.

This prevents partial schema changes.

This makes deployments much safer.

---

# 8. Why Fixed Schema?

Enterprise applications usually expect a predefined file format.

Example:

```text
topic_slug
question_text
option1
option2
option3
option4
correct_answer
```

If another CSV contains unexpected columns:

```text
employee_name
salary
department
```

The application rejects the file.

The uploaded file does **not** decide the database schema.

The application defines the expected schema.

---

# 9. Validation

Validation should happen before writing data into the database.

Typical validations include:

* Required columns
* Empty files
* Missing values
* Invalid values
* Business rules

Invalid files should never reach the database.

---

# 10. Enterprise Database Design

Instead of storing everything in one table:

```text
uploaded_questions
```

Enterprise applications separate metadata from business data.

Example:

```text
upload_transactions
```

Stores:

* File Name
* Status
* Upload Time
* Processing Time
* Validation Errors

and

```text
uploaded_questions
```

Stores the actual question records.

Relationship:

```text
One Upload

↓

Many Questions
```

This provides better traceability and troubleshooting.

---

# 11. Why Indexes?

Indexes improve read performance.

Without an index:

The database scans every row.

```text
Row 1

Row 2

Row 3

...

Row 10,000,000
```

With an index:

The database directly jumps to the required records.

Indexes are similar to the index page of a book.

They improve searching.

---

# 12. Should Every Column Have an Index?

No.

Indexes improve reading.

Indexes slightly slow writing because every insert or update also updates the index.

Indexes should only be created for columns that are frequently searched or joined.

---

# 13. Batch Inserts

Writing one row at a time is inefficient.

Instead of:

```text
Insert Row 1

Insert Row 2

Insert Row 3
```

Enterprise systems usually insert:

```text
5000 Rows

Commit

Next 5000 Rows

Commit
```

Batch inserts reduce database overhead.

---

# 14. Connection Pooling

Connection Pooling and Batch Inserts solve different problems.

Connection Pool:

Optimizes database connections.

Batch Insert:

Optimizes database writes.

A connection pool maintains reusable database connections.

Applications borrow a connection, use it, and return it to the pool.

Connections are reused instead of recreated.

---

# 15. Connection Pool vs One Connection

One connection can process many batch inserts.

```text
Open Connection

Batch 1

Batch 2

Batch 3

Close Connection
```

This is perfectly valid.

Connection pooling becomes useful when many users or services access the database simultaneously.

---

# 16. How Enterprise Applications Handle Concurrency

Instead of creating a new database connection for every request:

```text
Request

↓

Connection Pool

↓

Available Connection

↓

Database

↓

Return Connection
```

If every connection is busy, new requests wait until one becomes available.

Connections are reused.

They are not shared simultaneously.

---

# Key Takeaways

* Separate responsibilities between services.
* Backend should focus on business logic.
* Lambda should focus on processing.
* Migrations should manage database schema.
* Database schema should be version-controlled.
* Validate data before writing.
* Use fixed schemas for business applications.
* Separate metadata from business data.
* Use indexes carefully.
* Batch inserts improve write performance.
* Connection pooling improves scalability.
* Build systems that are easy to maintain, debug and extend.

---

## ORM vs Database Foreign Key

Although both represent relationships between tables, they serve different purposes.

### Database Foreign Key

* Enforced by the database (PostgreSQL).
* Maintains referential integrity.
* Prevents invalid data from being inserted.
* Ensures a child record always references an existing parent record.

Example:

```text
uploaded_questions.transaction_id
        │
        ▼
upload_transactions.id
```

If the referenced transaction does not exist, PostgreSQL rejects the insert.

---

### SQLAlchemy ORM Relationship

* Exists only in the application layer.
* Provides convenient object navigation.
* Does **not** create or enforce database constraints.
* SQLAlchemy automatically executes the required SQL queries behind the scenes.

Examples:

```python
transaction.uploaded_questions
```

```python
question.transaction
```

The ORM relationship makes the code cleaner, while the database Foreign Key protects data integrity.

---

## Architecture Responsibilities

A good enterprise design gives each component a single responsibility.

### Backend

Responsible for:

* Owning the database schema
* SQLAlchemy models
* Alembic migrations
* Creating and modifying database tables

The backend is the owner of the database structure.

### Lambda

Responsible for:

* Reading the CSV from S3
* Parsing the CSV
* Validating the data
* Writing data into existing database tables
* Updating processing status

Lambda does **not** own the database schema. It simply processes data and writes it into the existing schema.

---

## Data Flow

The application processes an uploaded CSV in the following order:

```text
User Upload

↓

Backend API

↓

Amazon S3 (Inbound)

↓

Lambda Trigger

↓

Read CSV

↓

Parse CSV

↓

Validate Data

↓

Insert Upload Transaction

↓

Database generates transaction_id

↓

Insert Uploaded Questions

↓

Update Transaction Status

↓

Success
```

Business data comes from the uploaded CSV.

System data (transaction ID, timestamps, status, etc.) is generated by the application during processing.

---

## Key Learning

Always separate **business data** from **system-generated metadata**.

**Business Data**

* topic_slug
* question_text
* options
* correct_answer

**System Data**

* transaction_id
* created_at
* uploaded_at
* processed_at
* status

This separation makes the application easier to maintain, audit, and extend.

---


