# RDS vs Aurora Architecture

## Overview

In this project, I am using two different database architectures depending on the environment:

* **Dev Environment** → Amazon RDS PostgreSQL Instance
* **Prod Environment** → Amazon Aurora PostgreSQL Cluster

The goal is to keep development environments simple and cost-effective while providing high availability and scalability in production.

---

# 1. Amazon RDS Instance Architecture

## What is RDS?

Amazon RDS (Relational Database Service) is a managed database service where AWS handles:

* Database provisioning
* OS patching
* Automated backups
* Monitoring
* Maintenance

I only need to focus on the application and database schema.

---

## Architecture

```text
Backend ECS Service
        │
        ▼
RDS Endpoint
        │
        ▼
PostgreSQL Database
```

Example:

```text
Backend
   │
   ▼
dojo-dev-rds.xxxxx.us-east-1.rds.amazonaws.com
   │
   ▼
PostgreSQL
```

---

## Benefits of RDS

### Simplicity

Easy to create and manage.

### Cost Effective

Suitable for:

* Development
* Testing
* Small applications

### Managed Service

AWS handles:

* Backups
* Patching
* Monitoring

### Easy Integration

Backend applications can directly connect using:

```text
DATABASE_URL
```

---

## Limitations of RDS

### Single Writer

Only one database instance handles all reads and writes.

### Limited Scaling

Scaling usually requires:

* Vertical scaling (bigger instance)
* Read replicas

### Lower Availability

If the instance becomes unavailable, recovery takes longer compared to Aurora.

---

# 2. Amazon Aurora Cluster Architecture

## What is Aurora?

Aurora is AWS's cloud-native relational database engine built for:

* High Availability
* High Performance
* Automatic Failover
* Better Scalability

Aurora is compatible with PostgreSQL and MySQL.

---

## Architecture

```text
Backend ECS Service
        │
        ▼
Aurora Cluster Endpoint
        │
        ▼
Aurora Writer
        │
 ┌──────┴──────┐
 ▼             ▼
Reader 1    Reader 2
```

Example:

```text
Backend
   │
   ▼
Cluster Endpoint
   │
   ▼
Writer Instance
   │
 ┌─┴─┐
 ▼   ▼
Reader Reader
```

---

## Benefits of Aurora

### High Availability

Aurora automatically replicates data across multiple Availability Zones.

### Automatic Failover

If the writer fails:

```text
Reader
   ▼
Promoted to Writer
```

with minimal downtime.

### Better Performance

Aurora can provide significantly higher throughput compared to standard PostgreSQL.

### Read Scaling

Multiple reader instances can serve read traffic.

### Cluster Endpoints

AWS manages:

* Writer Endpoint
* Reader Endpoint

Applications do not need to know which node is active.

---

## Limitations of Aurora

### Higher Cost

Aurora is more expensive than a standard RDS instance.

### More Components

Requires:

* Cluster
* Writer Instance
* Reader Instance(s)

### Operational Complexity

More moving parts compared to a single RDS instance.

---

# Why Use RDS for Dev and Aurora for Prod?

## Dev Environment

Requirements:

* Low cost
* Simplicity
* Easy testing

Solution:

```text
RDS PostgreSQL Instance
```

---

## Prod Environment

Requirements:

* High availability
* Scalability
* Automatic failover
* Better performance

Solution:

```text
Aurora PostgreSQL Cluster
```

---

# Database Connection Flow

## Dev

```text
ECS Backend
      │
      ▼
RDS Endpoint
      │
      ▼
PostgreSQL Database
```

Connection Example:

```text
postgresql://user:password@rds-endpoint:5432/mydb
```

---

## Prod

```text
ECS Backend
      │
      ▼
Aurora Cluster Endpoint
      │
      ▼
Writer Instance
      │
      ▼
Database
```

Connection Example:

```text
postgresql://user:password@cluster-endpoint:5432/mydb
```

---

# Key Takeaways

* RDS is simple, cost-effective, and suitable for development environments.
* Aurora is designed for production workloads requiring high availability and scalability.
* RDS uses a single database instance.
* Aurora uses a cluster architecture with writer and reader nodes.
* Aurora supports automatic failover and read scaling.
* Backend services connect using a database connection string (`DATABASE_URL`).
* Using Terraform variables ensures a single source of truth for database configuration across environments.
