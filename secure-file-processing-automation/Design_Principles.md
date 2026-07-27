# SYSTEM_DESIGN.md

# Event-Driven File Processing Architecture
## (S3 → Lambda → Database & Enterprise Design Concepts)

---

# Overview

This document explains the system design concepts behind the first project:

```
User
   │
   ▼
Application
   │
   ▼
Amazon S3
   │
   ▼
Lambda
   │
   ▼
PostgreSQL
```

The objective is to understand **why enterprises use this architecture instead of directly inserting data into the database**.

---

# Problem Statement

Suppose an application allows users to upload CSV files.

Each CSV contains hundreds or thousands of records.

Example:

```
employees.csv
```

```
EmployeeID,Name,Department
101,Rahul,Engineering
102,Priya,Finance
```

After uploading,

the application should

- validate the data
- parse the CSV
- insert into PostgreSQL
- update transaction status

There are two possible designs.

---

# Design 1

## Direct Upload

```
User
   │
   ▼
Backend API
   │
   ▼
Parse CSV
   │
   ▼
Database
```

---

## Advantages

- Simple architecture
- Easy to develop
- Immediate response to user
- Suitable for small files

---

## Problems

### 1. Long Request Time

The backend keeps the HTTP request open while

- reading CSV
- validating
- inserting records

The user waits until everything finishes.

---

### 2. Backend Becomes Busy

If many users upload files simultaneously,

the backend must process every upload itself.

Instead of serving new users,

it spends time parsing files.

---

### 3. Database Connections Stay Open

While processing,

the backend keeps a database connection active.

Long-running uploads increase resource usage.

---

### 4. Failure Recovery

Suppose

```
CSV

↓

Parse

↓

Database Failure
```

The request fails.

Often the user must upload the file again.

Unless the application stores the original file,

it cannot retry processing.

---

### 5. Tight Coupling

The backend becomes responsible for

- file upload
- parsing
- validation
- database insertion
- retries
- logging
- notifications

Every new feature increases complexity.

---

# Design 2

## Event-Driven Architecture

```
User
   │
   ▼
Application
   │
   ▼
Amazon S3
   │
   ▼
S3 Event
   │
   ▼
Lambda
   │
   ▼
PostgreSQL
```

---

# Responsibilities

Application

Only uploads the file.

---

Amazon S3

Safely stores the uploaded file.

---

Lambda

Processes the file.

- Read
- Parse
- Validate
- Insert
- Update status

---

Database

Stores processed records.

---

# Why Use S3?

Many beginners think

> "Why not upload directly to the database?"

The answer is **decoupling**.

Instead of

```
Upload

↓

Process

↓

Database
```

the application simply performs

```
Upload

↓

Done
```

Everything else happens automatically.

---

# Advantages of S3

## 1. Durable Storage

The uploaded file remains safely stored.

Even if processing fails,

the file still exists.

It can be processed again later.

---

## 2. Retry Capability

Suppose Lambda fails.

```
S3

↓

Lambda

↓

Database ❌
```

No data is lost.

The file is still inside S3.

The processing can be retried without asking the user to upload again.

---

## 3. Audit Trail

Suppose six months later

the business asks

> Why did this upload fail?

The original CSV still exists.

The operations team can download it,

inspect it,

and process it again if required.

---

## 4. Decoupling

The application no longer knows

- database schema
- parsing logic
- validation rules

Its only responsibility is uploading files.

---

## 5. Scalability

Multiple services can react to the same upload.

Example

```
S3

├── Lambda → Database
├── Lambda → Email
├── Lambda → Analytics
├── Lambda → Notifications
└── Lambda → Logging
```

One upload can trigger many independent workflows.

---

# Duplicate Handling

Uploading the same file twice should not create duplicate records.

Example

```
questions.csv
```

uploaded twice.

Without validation,

the database stores duplicate data.

Enterprise systems usually detect duplicates using

- File Name
- Object Key
- MD5 Hash
- SHA256 Hash
- Transaction History

If duplicate,

the upload is skipped.

Example

```
Status

DUPLICATE
```

---

# Validation

Before inserting,

Lambda validates

- mandatory columns
- data types
- business rules
- allowed values

Example

```
Correct Answer

8
```

If only

```
1

2

3

4
```

are valid,

the upload fails.

---

# Retry Strategy

Temporary failures happen.

Examples

- Database restart
- Network issue
- Timeout

Instead of failing immediately,

Lambda retries.

Only after retry attempts fail,

the transaction becomes

```
FAILED
```

---

# Transaction Handling

The project uses database transactions.

```
Insert Upload Transaction

↓

Insert Questions

↓

Update Status

↓

Commit
```

If anything fails,

```
Rollback
```

ensures no partial data remains.

---

# Why Lambda?

Lambda is excellent for

- event-driven processing
- short execution
- automatic scaling
- pay-per-use workloads

Examples

- CSV Parsing
- JSON Processing
- Image Resize
- PDF Processing

---

# Lambda Limitations

Lambda has service limits.

Examples

- Maximum execution time: 15 minutes
- Configurable memory (128 MB to 10 GB)
- Limited temporary storage unless configured

Large workloads may exceed these limits.

---

# When Lambda Is NOT Suitable

Examples

- 20 GB CSV
- Video transcoding
- Malware scanning for hours
- ML preprocessing
- Large ETL jobs

For these,

containers are usually preferred.

---

# ECS Architecture

Instead of

```
S3

↓

Lambda
```

the architecture becomes

```
S3

↓

SQS

↓

ECS
```

---

# Why Introduce SQS?

SQS acts as a buffer.

Instead of directly invoking workers,

messages wait safely inside the queue.

Example

```
100 Uploads

↓

100 Messages
```

Workers process messages one by one.

Nothing is lost.

---

# ECS Auto Scaling

Suppose

100 files arrive.

The system does NOT start one huge container.

Instead,

CloudWatch observes the queue.

Example

```
Queue = 100 Messages

↓

Desired Count = 20

↓

20 ECS Tasks
```

Each task processes a different message.

This is called **horizontal scaling**.

---

# Horizontal Scaling

Instead of

```
1 Container

16 CPU

64 GB RAM
```

the system prefers

```
20 Containers

2 CPU

4 GB RAM each
```

The workload is distributed.

This improves

- availability
- scalability
- fault isolation

---

# What Happens if One Task Fails?

Suppose

Task 8 crashes.

Only that message is affected.

The remaining tasks continue processing.

This makes the architecture resilient.

---

# Processing Huge Files

Suppose

```
20 GB CSV
```

Loading everything into memory is inefficient.

Enterprise applications usually

- stream data
- process in chunks
- avoid loading the entire file into RAM

This reduces memory usage.

---

# Why ECS Instead of Lambda for Malware Scanning?

Malware scanning

- uses ClamAV binaries
- consumes CPU
- consumes memory
- execution time varies

Containers provide

- configurable CPU
- configurable memory
- configurable storage
- no 15-minute execution limit

Therefore,

ECS is a better fit.

---

# Comparing Both Projects

## Project 1

```
S3

↓

Lambda

↓

Database
```

Purpose

Fast event-driven data ingestion.

Examples

- Quiz Upload
- Employee Upload
- Inventory Import
- Banking Transactions

---

## Project 2

```
S3

↓

SQS

↓

ECS

↓

Malware Scan
```

Purpose

Long-running compute-intensive processing.

Examples

- Antivirus Scan
- Video Processing
- Large Document Analysis
- Image Rendering

---

# Key Design Principles Learned

- Decouple upload from processing.
- Store uploaded files safely before processing.
- Process asynchronously whenever possible.
- Validate data before writing to the database.
- Retry transient failures.
- Avoid duplicate processing.
- Use transactions to maintain consistency.
- Choose Lambda for lightweight event-driven workloads.
- Choose ECS for CPU-intensive or long-running workloads.
- Scale horizontally by increasing the number of workers instead of creating one extremely powerful server.
- Use queues to absorb traffic spikes and smooth workload distribution.

---

# Final Takeaway

The decision is **not** "Lambda vs ECS."

The decision is based on the characteristics of the workload.

| Workload | Best Choice |
|----------|-------------|
| Small, event-driven, short-running file processing | S3 → Lambda |
| Long-running, CPU-intensive, large-file processing | S3 → SQS → ECS |
| Many concurrent uploads | Queue + Auto Scaling |
| Need retries and durability | Store files in S3 first |
| Need auditability | Preserve original files in S3 |

A good system design always starts by understanding **the workload, expected scale, failure scenarios, and business requirements**, then choosing the architecture that best fits those characteristics.