# AWS RDS — Quick Revision Notes

# What is RDS?

RDS (Relational Database Service) is AWS managed database service.

AWS handles:

* backups
* patching
* maintenance
* failover
* monitoring

Supported DB engines:

* PostgreSQL
* MySQL
* MariaDB
* Oracle
* SQL Server

---

# Why Use RDS Instead of DB Inside EC2?

| DB in EC2          | RDS                |
| ------------------ | ------------------ |
| Manual maintenance | AWS managed        |
| Manual backups     | Automated backups  |
| Hard scaling       | Easy scaling       |
| High risk          | High availability  |
| Manual failover    | Automatic failover |

---

# Our Architecture

```text id="v4x4mo"
Private EC2
     ↓
RDS PostgreSQL
```

RDS remained:

* private
* secure
* isolated inside VPC

---

# Important RDS Concepts

---

# 1. DB Instance

Actual running database server.

Example:

```text id="d6jv7m"
PostgreSQL 17
```

---

# 2. Endpoint

RDS connection URL.

Example:

```text id="8c0oln"
sp-rds-db.xxxxx.us-east-1.rds.amazonaws.com
```

Applications use endpoint to connect.

---

# 3. Port

Database listening port.

| Database   | Default Port |
| ---------- | ------------ |
| PostgreSQL | 5432         |
| MySQL      | 3306         |

---

# 4. Storage

Disk size allocated to DB.

Example:

```text id="6r9mhh"
20 GB
100 GB
500 GB
```

Stores:

* tables
* indexes
* logs
* backups

---

# 5. IOPS (Important)

IOPS = Input Output Operations Per Second

Measures:

* disk performance
* database speed

---

# High IOPS Needed For

* banking systems
* high traffic apps
* analytics
* heavy queries

---

# Low IOPS Enough For

* small apps
* dev environments
* testing

---

# Simple Understanding

```text id="1q5n0u"
More IOPS = Faster DB Reads/Writes
```

---

# Storage Types

| Storage   | Usage            |
| --------- | ---------------- |
| gp2 / gp3 | General purpose  |
| io1 / io2 | High performance |
| Magnetic  | Old legacy       |

---

# Real Projects Mostly Use

```text id="r1vpkm"
gp3
```

because:

* cheaper
* good performance
* flexible

---

# 6. Multi-AZ

Creates standby DB in another Availability Zone.

If primary DB fails:

```text id="i6r39k"
AWS automatically fails over
```

Used for:

* high availability
* disaster recovery

---

# 7. Read Replica

Creates read-only copy of DB.

Used for:

* reporting
* analytics
* heavy read traffic

---

# Flow

```text id="bz85l5"
Writes → Primary DB
Reads  → Replica DB
```

---

# 8. Automated Backups

AWS automatically takes backups.

Can restore database to:

* previous date
* previous time

---

# 9. Snapshot

Manual database backup.

Used before:

* migrations
* upgrades
* risky deployments

---

# 10. Public vs Private RDS

---

# Public RDS

Accessible from internet.

❌ Not recommended for production

---

# Private RDS

Accessible only inside VPC.

✅ Used in our project

---

# Security Group Rule We Used

| Port | Source         |
| ---- | -------------- |
| 5432 | Private EC2 SG |

Meaning:

```text id="vb1nj5"
Only application servers can access DB
```

---

# 11. DB Subnet Group

RDS requires minimum 2 subnets across AZs.

Why?

For:

* failover
* HA
* Multi-AZ support

---

# 12. Backup Retention

Controls how many days backups kept.

Example:

```text id="o53j7y"
7 days
30 days
35 days
```

---

# 13. Maintenance Window

AWS patching time slot.

Used for:

* updates
* security patches
* minor upgrades

Usually configured during:

* low traffic hours

---

# 14. Encryption

RDS supports:

* storage encryption
* backup encryption

Uses:

* AWS KMS

---

# 15. Monitoring

RDS integrates with:

* CloudWatch
* Performance Insights

Tracks:

* CPU
* memory
* storage
* connections
* slow queries

---

# Important Real Project Settings

| Setting          | Common Value |
| ---------------- | ------------ |
| Engine           | PostgreSQL   |
| Storage Type     | gp3          |
| Multi-AZ         | Enabled      |
| Public Access    | Disabled     |
| Backup Retention | 7 days       |
| Monitoring       | Enabled      |
| Encryption       | Enabled      |

---

# Common Interview Questions

---

# Q) Why use RDS instead of PostgreSQL inside EC2?

### Answer

```text id="5ycyo2"
RDS reduces operational overhead because AWS handles backups,
patching, monitoring, failover, and maintenance automatically.

It provides high availability, scalability, and better reliability
compared to self-managed databases inside EC2.
```

---

# Q) What is Multi-AZ in RDS?

### Answer

```text id="gqzxw3"
Multi-AZ creates a standby database in another Availability Zone.
If primary DB fails, AWS automatically performs failover to standby DB,
improving high availability and disaster recovery.
```

---

# Q) Difference Between Multi-AZ and Read Replica?

| Multi-AZ           | Read Replica          |
| ------------------ | --------------------- |
| High availability  | Read scaling          |
| Standby DB         | Read-only DB          |
| Automatic failover | No automatic failover |
| Same data sync     | Async replication     |

---

# Q) What is IOPS?

### Answer

```text id="v9rlnv"
IOPS means Input Output Operations Per Second.
It measures database disk performance.

Higher IOPS improves database read/write speed and query performance.
```

---

# Q) Why Keep RDS Private?

### Answer

```text id="2ul4v5"
Keeping RDS private improves security by preventing direct internet access.
Only backend application servers inside VPC can communicate with database.
```

---

# Final One-Line Summary

```text id="rjlwmx"
RDS = Managed, scalable, highly available relational database service on AWS.
```
