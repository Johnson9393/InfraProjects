# Database Migration Learning Journey

## Overview

This document captures my learning journey on how database management evolves from a simple application to an enterprise-grade deployment model.

Initially, I focused on making the application work. As I progressed, I learned why large organizations separate database migrations from application code and how different architectures handle deployments safely.

---

# Phase 1 - Creating Tables Inside the Application

## Initial Approach

In my first Flask application, database tables were created directly from the application using:

```python
db.create_all()
```

Flow:

```text
Application Starts
        │
        ▼
db.create_all()
        │
        ▼
Tables Created
```

### Advantages

* Very easy to learn
* Quick setup
* Good for personal projects
* Suitable for prototypes

### Limitations

* No version history of database changes
* Difficult to track schema evolution
* Harder to manage rollbacks
* Not suitable for enterprise applications

**Real-world analogy**

Imagine constructing a building without maintaining architectural drawings. The building may work today, but modifying it later becomes difficult because there is no record of what changed over time.

---

# Phase 2 - Versioned Database Migrations

Instead of creating tables directly from the application, I learned to maintain database changes as migration files.

Flow:

```text
Migration Files
        │
        ▼
Migration Tool
        │
        ▼
Database Updated
```

Every schema change is stored as a versioned migration.

Examples:

```text
V1__Create_users_table
V2__Add_email_column
V3__Create_orders_table
```

### Advantages

* Database changes are version controlled
* Easier rollback strategy
* Safer deployments
* Complete history of schema changes

---

# Phase 3 - My DevOps Dojo Project

In my DevOps Dojo project, I learned to execute database migrations as a separate deployment stage.

Deployment Flow

```text
Build Docker Image
        │
        ▼
Push Image to ECR
        │
        ▼
Run ECS Migration Task
        │
        ▼
Migration Successful
        │
        ▼
Deploy ECS Services
```

The migration task executes before the application is updated.

If the migration fails, deployment stops immediately.

### Benefits

* Database is updated before application deployment
* Existing application remains unaffected if migration fails
* Easier troubleshooting
* Clear separation between database updates and application deployment

---

# Phase 4 - My Company's Production Architecture

In my current project, database migrations are handled differently.

Deployment Flow

```text
Build Docker Image
        │
        ▼
Push Image
        │
        ▼
Deploy to EKS
        │
        ▼
Spring Boot Starts
        │
        ▼
Flyway Executes
        │
        ▼
Application Becomes Ready
```

Flyway automatically checks whether new migration versions exist.

If no new migrations are found:

```text
Start Application
```

If new migrations are found:

```text
Execute New Migrations
        │
        ▼
Start Application
```

If a migration fails, the application startup fails, preventing an inconsistent deployment.

---

# The Biggest Learning

Both architectures solve the same problem.

The only difference is **when** database migrations are executed.

## DevOps Dojo

```text
Pipeline
      │
Run Migration
      │
Deploy Application
```

Migration happens **before deployment**.

---

## Company Project

```text
Deploy Application
      │
Application Starts
      │
Flyway Executes
```

Migration happens **during application startup**.

Both approaches are valid and commonly used in production environments.

---

# Important Observation

Whether using Alembic or Flyway:

* Old migrations are **not executed again**
* Only newly added migration versions are applied

Example:

Existing migrations:

```text
V1
V2
V3
```

Developer adds:

```text
V4
```

Next deployment:

```text
V1 ✔ Skip
V2 ✔ Skip
V3 ✔ Skip
V4 ✔ Execute
```

---

# Real-World Analogy

Imagine renovating a hotel.

### Old Approach

Every time the hotel opens, workers try to rebuild every room.

This wastes time and creates unnecessary risk.

---

### Versioned Migration Approach

The renovation team keeps a logbook.

```text
Room 101 Renovated ✔
Room 102 Renovated ✔
Room 103 Renovated ✔
```

When a new room needs renovation:

```text
Only Room 104 is renovated.
```

Previously completed work is never repeated.

This is exactly how Flyway and Alembic work.

---

# Key Learnings

* Creating tables directly inside the application is suitable for learning but not ideal for enterprise systems.
* Database schema changes should be version controlled using migration tools.
* Separating database migrations from business logic improves maintainability.
* DevOps Dojo performs migrations as a dedicated deployment stage before updating the application.
* My company's project performs migrations automatically during Spring Boot startup using Flyway.
* Both architectures achieve the same goal; they differ only in the point at which migrations are executed.
* Migration tools execute **only pending versions**, not previously applied migrations.
* Understanding deployment order and migration strategy is essential for troubleshooting production systems.

---
