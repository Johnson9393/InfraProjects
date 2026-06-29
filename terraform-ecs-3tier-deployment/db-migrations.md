# Database Migrations - Flyway vs DB Scripts

## Overview

Database changes are different from application changes.

Application code can usually be rolled back easily, but database changes require extra care because they can affect existing production data.

For this reason, database changes are often managed separately from application deployments.

---

# Two Common Approaches

## 1. Flyway Migrations

Flyway is a database migration tool that manages schema changes in a controlled and versioned manner.

Example migration:

```sql
ALTER TABLE users
ADD COLUMN email VARCHAR(255);
```

Flyway tracks which migrations have already been executed and only runs new ones.

### Flow

```text
Developer Creates Migration
          ↓
Commit to Repository
          ↓
CI/CD Pipeline
          ↓
Flyway Migration
          ↓
Database Updated
          ↓
Application Deployment
```

### Benefits

* Version controlled database changes
* Automated execution
* Repeatable deployments
* Easy tracking of schema history

---

# How Flyway Works

Flyway maintains a history table inside the database.

Example:

```text
V1 - Create Users Table
V2 - Add Email Column
V3 - Create Orders Table
```

If V1, V2, and V3 have already been executed:

```text
Next Deployment
      ↓
No New Migration
      ↓
Nothing Runs
```

Flyway only executes migrations that have never been executed before.

---

## 2. Manual DB Scripts (Enterprise Approach)

Some organizations maintain a separate database script repository.

Example:

```text
db-scripts/
 ├── pre_migration.sql
 ├── migration.sql
 └── post_migration.sql
```

This approach is commonly used when database changes are sensitive or involve large amounts of production data.

---

# Deployment Flow Using DB Scripts

```text
Developer Provides DB Script
            ↓
Pre-Migration Validation
            ↓
Run Database Script
            ↓
Deploy Application
            ↓
Post-Migration Validation
```

---

# Pre-Migration Checks

Purpose:

* Verify existing data
* Record row counts
* Validate current state

Example:

```sql
SELECT COUNT(*) FROM users;
```

---

# Migration Script

Purpose:

* Add columns
* Modify tables
* Create indexes
* Update existing data

Example:

```sql
ALTER TABLE users
ADD COLUMN email VARCHAR(255);
```

---

# Post-Migration Checks

Purpose:

* Validate migration success
* Verify record counts
* Confirm no data loss

Example:

```sql
SELECT COUNT(*) FROM users;
```

---

# When to Use Flyway

Good for:

* Schema changes
* New tables
* New columns
* Index creation
* Automated deployments

Example:

```text
Add Column
Add Table
Add Index
```

---

# When to Use Manual DB Scripts

Good for:

* Large data migrations
* Production data corrections
* Backfilling millions of records
* High-risk database changes

Example:

```text
Mass Updates
Data Cleanup
Historical Data Migration
```

---

# Why Database Changes Are Treated Differently

Application rollback:

```text
Version 5
   ↓
Version 4
```

Usually straightforward.

Database rollback:

```text
Column Deleted
Data Removed
Rows Updated
```

May be difficult or impossible to reverse.

For this reason, database changes require additional validation and control.

---

# Recommended Production Flow

```text
Code Change
     ↓
Database Change Required?
     │
     ├── No
     │      ↓
     │   Deploy Application
     │
     └── Yes
            ↓
      Run Flyway or DB Script
            ↓
      Validate Database
            ↓
      Deploy Application
            ↓
      Post-Deployment Validation
```

---

# Key Takeaways

* Application deployments and database changes are separate concerns.
* Flyway manages versioned database schema changes automatically.
* Flyway only executes migrations that have not run before.
* Manual DB scripts provide greater control for complex production changes.
* Database rollbacks are harder than application rollbacks.
* Production systems should validate database changes before and after deployment.
* Database migrations should be planned carefully to avoid data loss and downtime.
