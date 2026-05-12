# answers.md

# Part 1 — RDS Architecture Selection

| Scenario                      | Best Choice       | Why                                              |
| ----------------------------- | ----------------- | ------------------------------------------------ |
| Personal blog, 200 visits/day | Single-AZ         | Cheap and sufficient for low traffic             |
| Hospital OT scheduling app    | Multi-AZ standby  | Needs high availability and automatic failover   |
| E-commerce site, read-heavy   | Multi-AZ Cluster  | Handles heavy reads using reader nodes           |
| Internal report tool          | Aurora Serverless | Auto pauses during idle time, saves cost         |
| Discord-like millions of DBs  | None of these     | RDS is not ideal; sharding/distributed DB needed |

---

# Why Database is Single Writer by Default?

Traditional relational databases maintain data consistency using transactions and locks.

If multiple writers update same data simultaneously:

* race conditions happen
* data corruption may occur
* consistency breaks

So relational DBs usually use:

```text id="q2f3u1"
One primary writer
```

and optional read replicas.

---

# What is Sharding?

Sharding means splitting database into smaller pieces across multiple servers.

Example:

```text id="x8m3ra"
Users A-M → DB1
Users N-Z → DB2
```

Benefits:

* horizontal scaling
* handles massive traffic
* reduces DB load

---

# Why Sharding Happens at Application Layer?

Because application understands:

* business logic
* user distribution
* partition strategy

Infrastructure alone cannot intelligently decide:

* where user data should live

---

# Why Disk Matters More Than CPU/RAM in Heavy Databases?

Heavy databases perform:

* reads
* writes
* transactions

Disk speed becomes bottleneck.

Slow storage means:

* slow queries
* slow commits
* slow transactions

Even strong CPU cannot help if disk is slow.

---

# What is IOPS?

IOPS = Input Output Operations Per Second

Measures how many:

* reads
* writes

disk can perform every second.

---

# More IOPS Means

```text id="w6r2af"
Faster database performance
```

especially during:

* high traffic
* heavy writes
* analytics queries

---

# Why IOPS Scales with Disk Size?

In AWS gp2 storage:

```text id="g5o4za"
Bigger disk = More baseline IOPS
```

because AWS allocates performance proportionally.

gp3 decouples storage and IOPS.

---

# What is Connection Pooling?

Instead of opening thousands of DB connections:

Application maintains reusable connection pool.

---

# Example

Without pooling:

```text id="n0s8wp"
1000 users = 1000 DB connections
```

Huge memory usage.

With pooling:

```text id="upzv7t"
1000 users share 50 DB connections
```

Efficient and scalable.

---

# Memory Calculation

If 1 DB connection uses:

```text id="v3k1bw"
10 MB
```

Then:

```text id="l4r6zc"
1000 × 10 MB = 10 GB RAM
```

Huge memory waste.

With 50 connection pool:

```text id="x0m2ep"
50 × 10 MB = 500 MB RAM
```

Much better.

---

# AWS KMS Key Types

| Type                  | Use Case                              |
| --------------------- | ------------------------------------- |
| AWS Managed Key       | Simple projects                       |
| Customer Managed Key  | More IAM control/auditing             |
| CloudHSM Imported Key | Strict compliance/security industries |

---

# Why We Used Private RDS?

To ensure:

* DB not exposed publicly
* only app EC2 can access DB
* better security

---

# Why Dedicated RDS Subnets?

Dedicated RDS subnets provide:

* network isolation
* better security
* cleaner routing
* easier NACL management

---

# Why Use ALB Health Check Path Instead of “/”?

We used:

```text id="m7n9yf"
/login
```

because:

* `/` redirected
* `/login` reliably returned valid response

In real production:

```text id="p9v4qh"
/health
```

endpoint is preferred.

---

# Route53 Routing Policies

| Policy       | Real Use Case                 |
| ------------ | ----------------------------- |
| Simple       | Single application            |
| Weighted     | Canary deployment             |
| Latency      | Nearest region routing        |
| Failover     | DR architecture               |
| Geolocation  | Country-based routing         |
| Geoproximity | Traffic shifting by geography |
| Multivalue   | Return multiple healthy IPs   |
| IP-based     | ISP/network-specific routing  |

---

# Why CPU-Based Scaling Alone is Bad?

CPU alone may not reflect real traffic.

---

# Example 1 — Uber Pattern

Many lightweight requests:

* huge traffic
* low CPU

CPU scaling fails.

---

# Example 2 — Black Friday

Traffic spikes suddenly.

CPU reacts too late.

Need:

* scheduled scaling
* predictive scaling

---

# Example 3 — Medium Pattern

Background jobs:

* high CPU
* low user traffic

Scaling unnecessarily increases cost.

---

# What is Scheduled Scaling?

Scaling based on known traffic patterns.

Example:

```text id="z2o8xr"
Scale to 10 servers every Friday 6 PM
```

Better for:

* predictable workloads
* business events

---

# What is Cooldown / Warmup Period?

New EC2 needs time to:

* boot OS
* run user_data
* install packages
* start app

Warmup prevents ASG from making wrong scaling decisions before instance becomes healthy.

---

# Difference Between EC2 Health Check and ELB Health Check

| EC2 Health Check        | ELB Health Check          |
| ----------------------- | ------------------------- |
| Checks VM status        | Checks actual application |
| OS-level                | App-level                 |
| Cannot detect app crash | Detects app failure       |

---

# Which One Detects Hung Gunicorn Process?

```text id="s4f6yw"
ELB Health Check
```

because ALB checks actual application response.

---

# Why ALB SG Allows 443 but ASG SG Allows Only ALB SG?

Security layering.

Users can access:

* ALB only

Users CANNOT directly access:

* private EC2

This protects backend servers from:

* direct attacks
* port scanning
* unauthorized access

---

# What Happens If DB Uses Same Route Table as App Tier?

Loses:

* network isolation
* tighter security boundaries
* independent NACL control

Dedicated RDS subnets provide cleaner architecture.

---

# Why Console Before Terraform in Bootcamp?

Console helps understand:

* networking
* dependencies
* AWS relationships
* real infrastructure flow

Terraform later automates what we already understand manually.

Without fundamentals:

* Terraform becomes copy-paste only.

---

# Why We Used ALB Instead of NLB?

Because application required:

* HTTP/HTTPS
* SSL termination
* health checks
* Route53 integration
* Layer 7 intelligent routing

ALB is ideal for web applications.

---

# Final Architecture Flow

```text id="c8k3te"
User
 ↓
Route53
 ↓
ALB (HTTPS)
 ↓
Target Group
 ↓
ASG EC2 Instances
 ↓
RDS PostgreSQL
```
