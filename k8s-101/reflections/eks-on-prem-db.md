# AWS EKS to On-Premises Database Connectivity

## 1. Basic Idea

The application is running in **AWS EKS**, but the database is running in the company's **on-premises data center**.

The goal is to allow the AWS application to communicate with the on-prem database using a **private network connection**, not by exposing the database to the internet.

```text
AWS
EKS Application
      |
      |
Private Network Connection
      |
      |
On-Premises
Database
```

---

## 2. Typical Enterprise Architecture

```text
                    AWS
        ┌─────────────────────────┐
        │                         │
        │   DEV VPC    PROD VPC   │
        │      |          |       │
        │     EKS        EKS      │
        │      |          |       │
        └──────┼──────────┼───────┘
               |          |
               └────┬─────┘
                    |
             Transit Gateway
                    |
             VPN / Direct Connect
                    |
              On-Prem Router
                    |
                 Firewall
                    |
             ┌──────┴──────┐
             |             |
           Dev DB        Prod DB
```

---

## 3. Core Components

### VPC

VPC is the private network inside AWS where the EKS cluster and other AWS resources live.

Think:

```text
VPC = AWS private network
```

---

### EKS

EKS runs the application.

For example:

```text
EKS Pod
10.20.1.25
```

The application needs to connect to:

```text
On-Prem DB
10.10.10.50:5432
```

---

### VPC Route Table

The route table is like a **direction board**.

It tells AWS:

```text
Destination          Where to send

10.20.0.0/16         Local VPC
10.10.0.0/16         Transit Gateway
0.0.0.0/0            NAT Gateway
```

So when the EKS pod wants:

```text
10.10.10.50
```

AWS sees:

```text
10.10.10.50
     ↓
10.10.0.0/16
     ↓
Transit Gateway
```

Core concept:

> **VPC Route Table decides the next place the packet should go.**

---

### Transit Gateway

Transit Gateway is a **central router**.

It connects multiple VPCs and networks.

For example:

```text
Dev VPC  ──┐
           |
Prod VPC ──┼── Transit Gateway ── On-Prem
           |
Other VPC ─┘
```

It receives the packet and determines that the destination belongs to the on-prem network.

Core concept:

> **Transit Gateway decides where traffic should go between connected networks.**

---

### VPN / Direct Connect

This is the **private road between AWS and on-premises**.

```text
AWS
 |
VPN / Direct Connect
 |
On-Prem
```

VPN uses an encrypted tunnel over the internet.

Direct Connect provides dedicated network connectivity and is commonly used in larger enterprise environments.

Core concept:

> **VPN / Direct Connect provides connectivity between AWS and the on-prem network.**

---

### On-Prem Router

Once the traffic reaches the company network, the on-prem router determines where the destination network is.

Example:

```text
Destination:
10.10.10.50

Router knows:
10.10.0.0/16 → Database Network
```

So it forwards the packet toward the database network.

Core concept:

> **The on-prem router moves the traffic to the correct internal network.**

---

### Firewall

The firewall controls whether the traffic is actually allowed.

Example:

```text
Source       → 10.20.0.0/16
Destination  → 10.10.10.50
Port         → 5432
Protocol     → TCP
```

The firewall can have:

```text
ALLOW
Dev VPC → Database : 5432

ALLOW
Prod VPC → Database : 5432

DENY
Everything else
```

Core concept:

> **Routing gets the packet there; the firewall decides whether it is allowed.**

---

## 4. Complete Request Flow

Suppose:

```text
EKS Pod:
10.20.1.25

Database:
10.10.10.50

Database Port:
5432
```

The application requests:

```text
10.10.10.50:5432
```

The packet travels:

```text
EKS Pod
   ↓
VPC Route Table
   ↓
Transit Gateway
   ↓
VPN / Direct Connect
   ↓
On-Prem Router
   ↓
Firewall
   ↓
Database
```

The database processes the request and sends the response back:

```text
Database
   ↓
Firewall
   ↓
On-Prem Router
   ↓
VPN / Direct Connect
   ↓
Transit Gateway
   ↓
VPC Route Table
   ↓
EKS Pod
```

### Complete one-line flow

```text
EKS Pod → VPC Route Table → Transit Gateway → VPN/Direct Connect → On-Prem Router → Firewall → Database → Firewall → On-Prem Router → VPN/Direct Connect → Transit Gateway → VPC Route Table → EKS Pod
```

---

## 5. Important Concept: Routing Works Both Ways

It is not enough to configure:

```text
AWS → On-Prem
```

The response must also know how to get back:

```text
On-Prem → AWS
```

So routes are required in both directions.

Think of it as a two-way road:

```text
AWS ─────────────→ Database
AWS ←───────────── Database
```

If the return path is missing, the connection will fail.

---

## 6. Dev and Prod

If there are multiple AWS accounts:

```text
Dev Account
   |
Dev VPC
   |
EKS
```

and:

```text
Prod Account
   |
Prod VPC
   |
EKS
```

Both can connect through a central Transit Gateway:

```text
Dev VPC ──┐
          |
Prod VPC ─┼── Transit Gateway ── On-Prem
          |
Other VPC ─┘
```

But Dev should normally not automatically have access to the Production database.

Example:

```text
Dev EKS  → Dev DB       ALLOW
Dev EKS  → Prod DB      DENY

Prod EKS → Prod DB      ALLOW
```

Firewall and routing policies are used to control this access.

---

## 7. DNS

Instead of putting the database IP directly into the application:

```text
10.10.10.50
```

the application can use a private DNS name:

```text
prod-db.company.internal
```

DNS resolves:

```text
prod-db.company.internal
        ↓
10.10.10.50
```

Remember:

> **DNS gives the database a name. Routing gets the traffic there.**

---

## 8. Database Credentials

Network connectivity and database authentication are two different things.

### Network question

```text
Can my EKS application reach the database?
```

### Authentication question

```text
Does my application have valid database credentials?
```

Credentials should normally be stored securely, for example:

```text
AWS Secrets Manager
        ↓
EKS Application
        ↓
Database Username/Password
        ↓
On-Prem Database
```

Do not hard-code database passwords in Kubernetes manifests or application code.

---

## 9. The Five Things to Remember

| Component            | Simple Meaning                     |
| -------------------- | ---------------------------------- |
| VPC                  | AWS private network                |
| VPC Route Table      | Decides the next direction         |
| Transit Gateway      | Central router                     |
| VPN / Direct Connect | Private road to on-prem            |
| Firewall             | Decides whether traffic is allowed |

---

## 10. The Most Important Mental Model

Think of the entire architecture as:

```text
APPLICATION
     ↓
EKS
     ↓
VPC ROUTING
     ↓
TRANSIT GATEWAY
     ↓
VPN / DIRECT CONNECT
     ↓
ON-PREM ROUTER
     ↓
FIREWALL
     ↓
DATABASE
```

And the response comes back through the reverse path.

### One sentence to remember

> **The application sends traffic → routing finds the path → Transit Gateway moves it between networks → VPN/Direct Connect carries it to on-prem → the router finds the internal network → the firewall allows or blocks it → the database responds through the reverse path.**
