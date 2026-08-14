# Kubernetes Control Plane High Availability, Consistency & Disaster Recovery

## Overview

The Kubernetes **Control Plane** is the brain of the cluster. It manages the entire Kubernetes environment and makes decisions such as:

- Scheduling Pods
- Managing Deployments
- Maintaining desired state
- Storing cluster information
- Responding to Kubernetes API requests

The Control Plane mainly consists of:

- API Server
- Scheduler
- Controller Manager
- **etcd (Source of Truth)**

---

# What is etcd?

**etcd** is a distributed key-value database used by Kubernetes.

It stores every object inside the cluster.

Examples:

- Pods
- Nodes
- Deployments
- Services
- Secrets
- ConfigMaps
- ReplicaSets

Think of etcd as:

```
Cluster Memory
```

or

```
Source of Truth
```

If etcd loses its data, Kubernetes loses the current state of the cluster.

---

# Why can't Kubernetes have multiple active Control Planes?

A common question is:

> "Why can't Kubernetes have two completely independent Control Planes running at the same time?"

The answer is **Data Consistency**.

Although EKS runs the control plane in a highly available manner, Kubernetes treats it as **one logical control plane** sharing the same consistent cluster state.

Running multiple independent control planes that make separate decisions can lead to conflicting cluster states.

---

# Split-Brain Problem

Imagine two independent control planes.

Control Plane A decides:

```
Schedule Pod → Worker Node 1
```

At the same time,

Control Plane B decides:

```
Schedule the same Pod → Worker Node 2
```

Now both control planes believe they are correct.

This situation is called **Split-Brain**.

The cluster becomes inconsistent because there is no single source of truth.

Kubernetes is designed to avoid this situation.

---

# Real-world Banking Example

Suppose a bank account has:

```
Balance = ₹10,000
```

Control Plane A processes:

```
Withdraw ₹500
```

Balance becomes:

```
₹9,500
```

At the same time,

Control Plane B still believes the balance is:

```
₹10,000
```

and processes another withdrawal.

Now two different balances exist.

This is unacceptable for critical systems like banking.

Therefore, Kubernetes always prioritizes **correct data** over **continuous availability**.

---

# What happens if the Control Plane fails?

Instead of allowing another independent control plane to continue making decisions, Kubernetes recovers the existing cluster state.

```
Control Plane Failure
        │
        ▼
Recover Control Plane
        │
        ▼
Restore etcd
        │
        ▼
Cluster becomes operational
```

There may be a short downtime, but the cluster state remains correct.

---

# What is High Availability (HA)?

High Availability means minimizing downtime by providing redundancy and fast recovery.

For Amazon EKS:

- AWS manages the Control Plane.
- Multiple API Server instances may exist for availability.
- etcd is replicated and managed by AWS.
- Users do not manage the Control Plane infrastructure.

---

# Backup and Recovery

AWS manages standard backups of the EKS control plane.

However, organizations should still define:

- Backup policies
- Disaster Recovery plans
- Automated recovery procedures

The goal is to restore the cluster quickly if a failure occurs.

---

# What is RTO?

**Recovery Time Objective (RTO)**

The maximum acceptable time to recover after a failure.

Example:

```
Application crashes

↓

Recover within 15 minutes
```

RTO = **15 minutes**

---

# What is RPO?

**Recovery Point Objective (RPO)**

The maximum acceptable amount of data loss.

Example:

Database backup every:

```
5 minutes
```

If the database fails, the maximum possible data loss is:

```
5 minutes
```

RPO = **5 minutes**

---

# Can a system achieve 100% uptime?

No.

Failures are inevitable.

Examples:

- Hardware failure
- Network failure
- Power outage
- Software bugs
- Human mistakes

Good system design focuses on **fast recovery**, not on trying to eliminate every possible failure.

---

# Consistency vs Availability

During a network failure, a distributed system cannot guarantee both perfect consistency and perfect availability simultaneously.

Kubernetes chooses:

```
Consistency
```

instead of

```
Availability
```

because protecting the cluster state is more important than keeping the API continuously available.

---

# Banking vs Typical Applications

### Banking Systems

Priority:

```
Data Consistency
```

Incorrect balances or duplicate transactions are unacceptable.

Short downtime is acceptable if it prevents incorrect data.

---

### Most Web Applications

Priority:

```
High Availability
```

Users prefer the application to remain available even if a small delay or retry is required.

Examples:

- E-commerce
- Social Media
- News Websites

---

# Key Learnings

- The Kubernetes Control Plane is the brain of the cluster.
- etcd is the source of truth for all Kubernetes objects.
- Multiple independent control planes can lead to Split-Brain problems.
- Kubernetes prioritizes **data consistency** over **continuous availability**.
- High Availability means recovering quickly from failures, not eliminating failures completely.
- RTO defines how quickly a system should recover.
- RPO defines how much data loss is acceptable.
- Good system design prepares for failures instead of assuming they will never happen.

---

# Interview Takeaways

**Q: What is etcd?**

A distributed key-value database that stores the complete state of the Kubernetes cluster.

---

**Q: Why doesn't Kubernetes allow multiple independent control planes?**

To prevent Split-Brain scenarios and maintain a single, consistent cluster state.

---

**Q: What happens if the Control Plane fails?**

Kubernetes restores the Control Plane and etcd, ensuring the cluster returns to a consistent state.

---

**Q: Why is consistency preferred over availability?**

Incorrect cluster state can cause scheduling conflicts and data corruption. Temporary downtime is preferable to inconsistent data.

---

# Simple Flow Diagram

```
                Kubernetes Cluster
                       │
                       ▼
                Control Plane
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   API Server      Scheduler    Controller Manager
                       │
                       ▼
                     etcd
              (Source of Truth)
                       │
                       ▼
                 Worker Nodes
                       │
                       ▼
                     Pods
```

---

# Final Takeaway

> **Failures are unavoidable. A well-designed Kubernetes system does not aim for impossible 100% uptime—it aims to recover quickly while preserving data consistency.**