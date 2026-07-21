# Database Reflections

> **Purpose:** This document serves as my one-stop reference for understanding how backend applications interact with databases, how schemas are managed, and how enterprise applications safely read and write data.

---

# 1. Database Architecture

A backend application does not communicate directly with PostgreSQL. Multiple layers are involved.

```text
Application
      │
      ▼
ORM / Database Toolkit (Optional)
      │
      ▼
Database Driver
      │
      ▼
PostgreSQL
```

### Real Project Example

Our project follows:

```text
Backend
    │
    ▼
SQLAlchemy Models
    │
    ▼
Alembic Migration
    │
    ▼
PostgreSQL
```

Lambda will directly communicate with PostgreSQL using raw SQL through a PostgreSQL driver.

---

# 2. What is an ORM?

ORM stands for **Object Relational Mapping**.

It maps programming language objects to database tables so developers work with objects instead of manually writing SQL for every operation.

### Responsibilities

* Maps classes to database tables.
* Maps object attributes to table columns.
* Performs CRUD operations.
* Generates SQL behind the scenes.

### Real Project Example

Python Model

```python
class UploadTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    file_name = db.Column(db.String(255))
```

This is only a Python class.

It does **not** create a table immediately.

SQLAlchemy understands this mapping.

Alembic later converts it into a migration.

### Enterprise Example

Java Spring Boot

```java
@Entity
public class Employee {
    @Id
    private Long id;
}
```

Hibernate maps this Java class to an Employee database table.

---

# 3. SQLAlchemy

SQLAlchemy is Python's ORM and Database Toolkit.

It provides:

* ORM
* Session Management
* Raw SQL Execution
* Database Abstraction

### Real Project Example

Our backend owns the database.

We created:

* upload_transactions model
* uploaded_questions model

SQLAlchemy maps these models to database tables.

Alembic then generates migration scripts.

---

# 4. Alembic

Alembic is Python's migration tool.

Responsibilities

* Detect schema changes
* Generate migration scripts
* Upgrade database
* Downgrade database
* Track schema version

### Real Project Example

We created:

```python
class UploadTransaction(db.Model):
```

Then executed:

```bash
flask db migrate -m "Add upload_transactions table"
```

Alembic generated

```python
op.create_table(...)
```

Then

```bash
flask db upgrade
```

created the table inside PostgreSQL.

---

# 5. Flyway

Flyway is a migration tool commonly used in Java applications.

Unlike Alembic,

Flyway **does not generate migrations automatically.**

Developers write SQL manually.

Example

```sql
CREATE TABLE upload_transactions(
    id SERIAL PRIMARY KEY,
    file_name VARCHAR(255)
);
```

Flyway executes this SQL and records it inside

```text
flyway_schema_history
```

---

# 6. Alembic vs Flyway

| Alembic                  | Flyway                     |
| ------------------------ | -------------------------- |
| Python                   | Java / Any Language        |
| Reads SQLAlchemy Models  | Reads SQL Scripts          |
| Auto-generates Migration | Manual Migration           |
| Uses alembic_version     | Uses flyway_schema_history |

### When to use?

Python + SQLAlchemy → Alembic

Java + Hibernate → Flyway

---

# 7. Database Drivers

A database driver is responsible for communicating with the database server.

Examples

| Language | Driver             |
| -------- | ------------------ |
| Python   | psycopg2 / psycopg |
| Java     | JDBC               |
| C#       | Npgsql             |

Responsibilities

* Open Connections
* Execute SQL
* Fetch Results
* Commit / Rollback

---

# 8. SQLAlchemy vs psycopg vs JDBC

Think of SQLAlchemy as a manager.

Think of psycopg and JDBC as messengers.

```text
Application

↓

SQLAlchemy

↓

psycopg Driver

↓

PostgreSQL
```

### Real Project Example

Backend

```python
UploadTransaction(db.Model)
```

↓

SQLAlchemy

↓

PostgreSQL

Lambda

```python
INSERT INTO upload_transactions...
```

↓

psycopg

↓

PostgreSQL

---

# 9. SQL Statement Structure

Standard SQL

```sql
INSERT INTO upload_transactions
(
    file_name,
    bucket_name,
    object_key,
    status
)
VALUES
(
    %s,
    %s,
    %s,
    %s
);
```

First Parentheses

→ Which columns?

Second Parentheses

→ What values?

Always specify column names.

Never rely on table column order.

---

# 10. Parameterized SQL

Never write

```python
query=f"INSERT ... {file_name}"
```

Always write

```python
cursor.execute(query, values)
```

Benefits

* Prevent SQL Injection
* Cleaner Code
* Enterprise Standard

### Real Project Example

Suppose someone uploads

```text
abc'); DROP TABLE upload_transactions; --
```

Bad Code

The SQL statement itself gets modified.

Good Code

The entire string is treated as plain text and stored as the file name.

Nothing is executed.

---

# 11. SQL Injection

SQL Injection happens when user input becomes part of the SQL statement.

Parameterized SQL prevents this by keeping

SQL

and

Data

completely separate.

Golden Rule

**SQL is fixed. Only data changes.**

---

# 12. Cursor

A Cursor executes SQL on behalf of the application.

Responsibilities

* Send SQL
* Pass Parameters
* Fetch Results

The cursor never creates SQL.

The application writes SQL.

The cursor only communicates with PostgreSQL.

Analogy

```text
Application

↓

Cursor

↓

Database

↓

Cursor

↓

Application
```

Think of it like a waiter in a restaurant.

---

# 13. Transactions

Changes are not permanent until

```python
commit()
```

If something fails

```python
rollback()
```

returns the database to its previous consistent state.

---

# 14. Transactional DDL

Example

```sql
CREATE TABLE A;

CREATE TABLE B;
```

If Table B creation fails,

Table A is automatically rolled back.

Database remains consistent.

---

# 15. Primary Key vs Foreign Key

Primary Key

* Unique row identifier.

Foreign Key

* References another table.
* Maintains relationships.
* Prevents orphan records.

### Real Project Example

upload_transactions

↓

id

↓

uploaded_questions

↓

transaction_id

One upload can have many uploaded questions.

---

# 16. ORM Relationship vs Database Foreign Key

Database Foreign Key

* Exists inside PostgreSQL.
* Enforces integrity.

ORM Relationship

* Exists only inside SQLAlchemy.
* Makes object navigation easier.

Both solve different problems.

---

# 17. Architecture Responsibility

Backend

* Owns Models
* Owns Database Schema
* Owns Alembic Migrations

Lambda

* Reads CSV
* Validates CSV
* Executes Business Logic
* Inserts Data
* Updates Upload Status

Lambda should never own the schema.

---

# 18. End-to-End Flow (Our Project)

```text
Developer

↓

Creates SQLAlchemy Model

↓

Alembic Migration

↓

PostgreSQL Table Created

────────────────────────────

User uploads CSV

↓

S3

↓

Lambda Trigger

↓

Read CSV

↓

Validate CSV

↓

Insert upload_transactions

↓

Get transaction_id

↓

Insert uploaded_questions

↓

Update upload status

↓

Archive / Error Folder
```

---

# Quick Revision (5-Minute Cheat Sheet)

* SQLAlchemy → Maps Python models to database tables.
* Alembic → Generates and applies schema migrations.
* Flyway → Executes developer-written SQL migrations.
* psycopg/JDBC → Database drivers that communicate with PostgreSQL.
* Cursor → Sends SQL and retrieves results.
* Parameterized SQL → Prevents SQL Injection.
* Primary Key → Unique identifier.
* Foreign Key → Relationship between tables.
* Backend owns the schema.
* Lambda processes data and writes into the existing schema.
* SQL is fixed; only data changes.
