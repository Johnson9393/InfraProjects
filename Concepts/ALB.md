# AWS Application Load Balancer (ALB) — Complete Deep Dive

# 1. Introduction

Application Load Balancer (ALB) is a Layer 7 load balancer provided by AWS under Elastic Load Balancing (ELB).

ALB intelligently distributes incoming HTTP and HTTPS traffic across multiple backend targets such as:

* EC2 Instances
* ECS Containers
* Kubernetes Pods
* Lambda Functions
* IP Targets

ALB works at:

```text
OSI Layer 7 → Application Layer
```

which means it understands:

* URLs
* HTTP headers
* Cookies
* Hostnames
* Query parameters
* Request paths

Unlike traditional Layer 4 load balancers, ALB can inspect application-level traffic and route requests intelligently.

---

# 2. Why Do We Need Load Balancer?

Suppose users directly access EC2:

```text
User → EC2
```

Problems:

* Single point of failure
* No scalability
* No HTTPS centralization
* No traffic distribution
* No failover
* No intelligent routing
* Direct exposure of EC2

If EC2 crashes:

```text
Application Down
```

---

# 3. What ALB Solves

With ALB:

```text
Users
   ↓
ALB
   ↓
Multiple Backend Servers
```

Benefits:

* High availability
* Intelligent routing
* HTTPS termination
* Health checks
* Traffic distribution
* Fault tolerance
* Auto scaling integration
* Centralized entry point

---

# 4. Why ALB is Called Layer 7 Load Balancer

ALB works at:

```text
Layer 7 → Application Layer
```

This means ALB can read actual HTTP request contents.

Example request:

```http
GET /api/users HTTP/1.1
Host: api.company.com
Cookie: session=abc
```

ALB can inspect:

* Path → /api/users
* Host → api.company.com
* Cookies
* Headers
* Query parameters

Then ALB decides:

```text
Which backend should receive traffic?
```

---

# 5. Layer 4 vs Layer 7

| Feature             | Layer 4 LB | Layer 7 ALB |
| ------------------- | ---------- | ----------- |
| Works on            | TCP/UDP    | HTTP/HTTPS  |
| Understands URLs    | No         | Yes         |
| Path-based routing  | No         | Yes         |
| Host-based routing  | No         | Yes         |
| Cookie routing      | No         | Yes         |
| SSL termination     | Limited    | Excellent   |
| Intelligent routing | No         | Yes         |

---

# 6. Real Traffic Flow

In our project:

```text
User
 ↓
Route53
 ↓
ALB
 ↓
Target Group
 ↓
Private EC2
 ↓
RDS
```

---

# 7. ALB Core Components

ALB mainly contains:

1. Listeners
2. Listener Rules
3. Target Groups
4. Health Checks
5. Security Groups
6. Availability Zones
7. SSL Certificates
8. Routing Engine

---

# 8. Listener

Listener waits for incoming traffic.

Example:

| Protocol | Port |
| -------- | ---- |
| HTTP     | 80   |
| HTTPS    | 443  |

In our project:

| Listener  | Purpose                   |
| --------- | ------------------------- |
| HTTP 80   | Initial testing           |
| HTTPS 443 | Secure production traffic |

---

# 9. Listener Workflow

Example:

```text
User opens:
https://infralabx.space
```

Traffic reaches:

```text
ALB Listener : 443
```

Listener checks rules:

```text
Forward traffic → Target Group
```

---

# 10. Listener Rules

Rules define routing behavior.

ALB can route based on:

* URL path
* Hostname
* HTTP headers
* Query parameters
* Source IP

---

# 11. Path-Based Routing

Example:

```text
/api/*     → API Servers
/admin/*   → Admin Servers
/images/*  → Image Servers
```

Flow:

```text
/api/users
     ↓
API Backend

/admin/dashboard
     ↓
Admin Backend
```

This is heavily used in microservices architecture.

---

# 12. Host-Based Routing

Example:

```text
api.company.com
     ↓
API Servers

admin.company.com
     ↓
Admin Servers
```

Single ALB can host multiple applications.

---

# 13. Target Group

ALB never directly forwards traffic to EC2.

Instead:

```text
ALB → Target Group → EC2
```

Target Group is a logical collection of backend servers.

---

# 14. Target Types

ALB supports 3 target types.

## Instance Target

```text
ALB → EC2
```

Used in our project.

---

## IP Target

```text
ALB → Private IP
```

Used in:

* Kubernetes
* On-prem systems
* Containers

---

## Lambda Target

```text
ALB → Lambda Function
```

Used in serverless architecture.

---

# 15. Health Checks

Health checks are one of the MOST IMPORTANT ALB features.

ALB continuously checks:

```text
Is backend healthy?
```

---

# 16. Why Health Checks Matter

Suppose EC2 crashes.

Without health checks:

```text
ALB still sends traffic
```

Users get:

* timeout
* 500 errors
* failures

---

# 17. With Health Checks

ALB periodically sends requests:

```http
GET /login
```

If server responds correctly:

```text
Healthy
```

Otherwise:

```text
Unhealthy
```

ALB immediately stops sending traffic to failed server.

---

# 18. Health Check Settings

| Setting             | Meaning       |
| ------------------- | ------------- |
| Path                | URL to check  |
| Interval            | How often     |
| Timeout             | Wait duration |
| Healthy Threshold   | Success count |
| Unhealthy Threshold | Failure count |

---

# 19. Example Health Logic

Suppose:

```text
Unhealthy Threshold = 2
```

If server fails twice:

```text
Marked Unhealthy
```

Suppose:

```text
Healthy Threshold = 5
```

If server succeeds 5 times:

```text
Marked Healthy Again
```

---

# 20. Security Groups

ALB has its own security group.

In our project:

| Port | Source    |
| ---- | --------- |
| 80   | 0.0.0.0/0 |
| 443  | 0.0.0.0/0 |

This allows internet traffic.

---

# 21. Backend Security Group

Private EC2 security group:

| Port | Source             |
| ---- | ------------------ |
| 8000 | ALB Security Group |

This ensures:

```text
Only ALB can access EC2
```

Very important production security practice.

---

# 22. Availability Zones

AWS requires ALB in minimum:

```text
2 Availability Zones
```

Reason:

High availability.

If one AZ fails:

```text
Traffic automatically flows through another AZ
```

---

# 23. SSL/TLS & HTTPS

HTTPS encrypts traffic.

Without HTTPS:

```text
Data visible on internet
```

With HTTPS:

```text
Encrypted secure communication
```

---

# 24. ACM (AWS Certificate Manager)

ACM manages SSL certificates.

Benefits:

* Free certificates
* Automatic renewal
* Easy ALB integration

---

# 25. SSL Termination

In our architecture:

```text
User
 ↓ HTTPS
ALB
 ↓ HTTP
EC2
```

ALB decrypts HTTPS traffic.

This is called:

```text
SSL Termination
```

Benefits:

* Lower EC2 CPU usage
* Easier certificate management
* Centralized SSL handling

---

# 26. Sticky Sessions

Normally:

```text
Request 1 → EC2-A
Request 2 → EC2-B
```

With sticky sessions:

```text
Same user → Same EC2
```

Used for:

* shopping carts
* legacy session apps

Modern stateless apps usually avoid this.

---

# 27. Cross-Zone Load Balancing

Without cross-zone balancing:

Traffic stays within same AZ.

Can create uneven load.

With cross-zone:

```text
ALB distributes traffic evenly across all instances
```

AWS ALB enables this automatically.

---

# 28. Deregistration Delay (Connection Draining)

Suppose EC2 removed during deployment.

Without draining:

```text
Active users disconnected immediately
```

With deregistration delay:

ALB waits before removing server.

Allows existing requests to finish safely.

---

# 29. ALB + Auto Scaling Integration

This is critical in production.

Flow:

```text
ASG launches new EC2
        ↓
EC2 boots application
        ↓
Health check passes
        ↓
Target Group marks healthy
        ↓
ALB starts routing traffic
```

If EC2 fails:

```text
Health check fails
        ↓
ALB stops traffic
        ↓
ASG replaces instance
```

---

# 30. Real Production Features

## WAF Integration

ALB integrates with AWS WAF.

Protects against:

* SQL injection
* XSS
* Bots
* Malicious traffic

---

## Access Logs

ALB can store logs in S3.

Useful for:

* analytics
* security auditing
* troubleshooting

---

## HTTP to HTTPS Redirect

Production best practice:

```text
HTTP 80
   ↓
Redirect
   ↓
HTTPS 443
```

---

## Idle Timeout

Controls connection lifetime.

Useful for:

* APIs
* uploads
* streaming

---

## WebSocket Support

ALB supports:

* real-time apps
* chat systems
* gaming
* live dashboards

---

# 31. ALB vs NLB vs CLB

| Feature      | ALB      | NLB                  | CLB         |
| ------------ | -------- | -------------------- | ----------- |
| Layer        | 7        | 4                    | Legacy      |
| HTTP aware   | Yes      | No                   | Limited     |
| Path routing | Yes      | No                   | No          |
| Host routing | Yes      | No                   | No          |
| WebSocket    | Yes      | Limited              | Limited     |
| Best for     | Web apps | High performance TCP | Old systems |

---

# 32. Best Practices in Real Projects

| Best Practice         | Reason      |
| --------------------- | ----------- |
| Use HTTPS only        | Security    |
| Keep EC2 private      | Security    |
| Use multiple AZs      | HA          |
| Use health checks     | Reliability |
| Enable access logs    | Monitoring  |
| Integrate with ASG    | Scalability |
| Use WAF               | Protection  |
| Redirect HTTP → HTTPS | Encryption  |

---

# 33. What We Configured in Our Project

| Component       | Configured |
| --------------- | ---------- |
| HTTP Listener   | Yes        |
| HTTPS Listener  | Yes        |
| ACM SSL         | Yes        |
| Route53         | Yes        |
| Health Checks   | Yes        |
| Target Group    | Yes        |
| Multi-AZ        | Yes        |
| ASG Integration | Yes        |
| Private EC2     | Yes        |

---

# 34. Final Production Architecture

```text
Internet
   ↓
Route53
   ↓
ALB (HTTPS)
   ↓
Target Group
   ↓
Private EC2 Instances
   ↓
RDS PostgreSQL
```

---

# 35. Key Interview Points

## Why ALB?

* Layer 7 intelligent routing
* HTTPS support
* Health checks
* Scalability
* High availability

---

## Why ALB instead of direct EC2?

* Security
* Fault tolerance
* Traffic distribution
* SSL termination

---

## Why ALB with ASG?

* Automatic scaling
* Self healing
* Zero downtime

---

# END
