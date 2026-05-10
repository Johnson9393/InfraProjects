```text id="arch-final"

                                            ┌──────────────────────────┐
                                            │         INTERNET         │
                                            └────────────┬─────────────┘
                                                         │
                                                         ▼
                                            ┌──────────────────────────┐
                                            │         Route53          │
                                            │     infralabx.space      │
                                            └────────────┬─────────────┘
                                                         │
                                                         ▼
                                            ┌──────────────────────────┐
                                            │    ACM SSL Certificate   │
                                            │       HTTPS : 443        │
                                            └────────────┬─────────────┘
                                                         │
                                                         ▼



╔══════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                        VPC : 10.0.0.0/16                                           ║
║                                                                                                      ║
║══════════════════════════════════════════════════════════════════════════════════════════════════════║
║                                         us-east-1a                                                   ║
║══════════════════════════════════════════════════════════════════════════════════════════════════════║
║                                                                                                      ║
║   ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐                        ║
║   │    PUBLIC SUBNET     │ │    PRIVATE SUBNET    │ │      RDS SUBNET      │                        ║
║   │     10.0.1.0/24      │ │      10.0.3.0/24     │ │      10.0.5.0/24     │                        ║
║   │                      │ │                       │ │                       │                        ║
║   │ ┌──────────────────┐ │ │ ┌──────────────────┐  │ │ ┌──────────────────┐ │                        ║
║   │ │       ALB        │ │ │ │       ASG        │  │ │ │    Amazon RDS   │ │                        ║
║   │ │                  │ │ │ │                  │  │ │ │    PostgreSQL   │ │                        ║
║   │ │  HTTP  : 80      │ │ │ │ Desired : 1     │  │ │ │   DB : mydb     │ │                        ║
║   │ │  HTTPS : 443     │ │ │ │ Min     : 1     │  │ │ │   Port : 5432   │ │                        ║
║   │ │                  │ │ │ │ Max     : 3     │  │ │ │                  │ │                        ║
║   │ └────────┬─────────┘ │ │ └────────┬─────────┘  │ │ └──────────────────┘ │                        ║
║   │          │           │ │          │            │ │                       │                        ║
║   │          ▼           │ │          ▼            │ │                       │                        ║
║   │ ┌──────────────────┐ │ │ ┌──────────────────┐  │ │                       │                        ║
║   │ │   Target Group   │◄┼─┼─│  EC2 APP SERVER  │──┼─┼───────────────────────┘                        ║
║   │ │   Port : 8000    │ │ │ │  Gunicorn App    │  │ │                                                ║
║   │ │ Health : /login  │ │ │ │  Flask App       │  │ │                                                ║
║   │ └──────────────────┘ │ │ │  Port : 8000     │  │ │                                                ║
║   └──────────────────────┘ │ └──────────────────┘  │ └──────────────────────┘                        ║
║                                                                                                      ║
║──────────────────────────────────────────────────────────────────────────────────────────────────────║
║                                         us-east-1b                                                   ║
║══════════════════════════════════════════════════════════════════════════════════════════════════════║
║                                                                                                      ║
║   ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐                        ║
║   │    PUBLIC SUBNET     │ │    PRIVATE SUBNET    │ │      RDS SUBNET      │                        ║
║   │     10.0.2.0/24      │ │      10.0.4.0/24     │ │      10.0.6.0/24     │                        ║
║   │                      │ │                       │ │                       │                        ║
║   │ ┌──────────────────┐ │ │ ┌──────────────────┐  │ │ ┌──────────────────┐ │                        ║
║   │ │   NAT Gateway    │ │ │ │ Future ASG EC2  │  │ │ │ Secondary RDS   │ │                        ║
║   │ │                  │ │ │ │                  │  │ │ │ Multi-AZ / HA   │ │                        ║
║   │ │ Elastic IP       │ │ │ │ Auto Scaling     │  │ │ │ Reserved Subnet │ │                        ║
║   │ └──────────────────┘ │ │ └──────────────────┘  │ │ └──────────────────┘ │                        ║
║   └──────────────────────┘ └──────────────────────┘ └──────────────────────┘                        ║
║                                                                                                      ║
║══════════════════════════════════════════════════════════════════════════════════════════════════════║
║                                   SHARED AWS SERVICES                                                ║
║══════════════════════════════════════════════════════════════════════════════════════════════════════║
║                                                                                                      ║
║   ┌──────────────────────────────────────────────────────────────────────────────────────────────┐   ║
║   │                                 VPC ENDPOINTS                                               │   ║
║   │                                                                                              │   ║
║   │   • S3 Gateway Endpoint                                                                      │   ║
║   │   • SSM Endpoint                                                                             │   ║
║   │   • SSMMessages Endpoint                                                                     │   ║
║   │   • EC2Messages Endpoint                                                                     │   ║
║   │                                                                                              │   ║
║   │   Attached to Private Route Tables                                                           │   ║
║   │   Enables AWS Service Access Without Public Internet                                         │   ║
║   └──────────────────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                                      ║
║   ┌──────────────────────────────────────────────────────────────────────────────────────────────┐   ║
║   │                               AWS SYSTEMS MANAGER (SSM)                                     │   ║
║   │                                                                                              │   ║
║   │   Secure EC2 Access Without SSH                                                              │   ║
║   │   Used Instead of Bastion After Initial Setup                                                │   ║
║   └──────────────────────────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                                      ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════════╝


                                                         │
                                                         ▼

                                      ┌────────────────────────────────────┐
                                      │             Amazon S3              │
                                      │                                    │
                                      │  • InfraProjects.zip              │
                                      │  • PostgreSQL .dump Backups       │
                                      └────────────────────────────────────┘

```

---

# 🧠 Architecture Explanation

---

# 🌍 Public Subnets

Used for internet-facing resources:

✅ ALB
✅ NAT Gateway

Reason:

* Must communicate with internet

---

# 🔒 Private Subnets

Used for:

✅ Application EC2 instances

Reason:

* Backend servers should never be public

---

# 🗄️ RDS Subnets

Used only for:

✅ PostgreSQL database

Reason:

* Database must remain isolated and secure

---

# 🚀 Traffic Flow

```text
User
 ↓
Route53
 ↓
ALB (HTTPS)
 ↓
Target Group
 ↓
Private EC2
 ↓
RDS
```

---

# 🔄 Auto Scaling Flow

If traffic increases:

```text
ASG launches new EC2 automatically
        ↓
Launch Template executes
        ↓
user_data installs app
        ↓
ALB health check passes
        ↓
Traffic starts flowing
```

---

# 📦 Backup Flow

```text
RDS
 ↓
pg_dump
 ↓
.dump file
 ↓
S3 Bucket
```

---

# 🔐 Security Design

| Resource | Public? |
| -------- | ------- |
| ALB      | ✅ Yes   |
| EC2      | ❌ No    |
| RDS      | ❌ No    |

---

# 🎯 Final Result

Built:

✅ Production-grade AWS architecture
✅ Highly available infrastructure
✅ Auto-scaling backend
✅ Secure private networking
✅ HTTPS secured application
✅ Managed database
✅ Automated deployment system
✅ Backup solution

```
```
