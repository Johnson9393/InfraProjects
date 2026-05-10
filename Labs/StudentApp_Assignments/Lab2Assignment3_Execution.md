# Part 15 — Application Load Balancer (ALB)

At this point:

✅ Application is running
✅ RDS connected
✅ systemd service working

But currently:

❌ Only accessible inside private EC2

Now we will expose application securely to internet.

---

# What is ALB?

ALB = Application Load Balancer

👉 It receives traffic from users and forwards traffic to backend servers.

---

# Why Do We Need ALB?

Without ALB:

❌ Users cannot access private EC2

With ALB:

✅ Public entry point
✅ Traffic distribution
✅ HTTPS support
✅ Health checks
✅ Future scalability with ASG

---

# Architecture Now

```text id="alb-arch"
User → ALB → Private EC2 → RDS
```

---

# Step 1 — Create ALB Security Group

Go to:

```text id="alb-1"
EC2 → Security Groups → Create
```

Name:

```text id="alb-2"
sp-alb-sg
```

---

# Add Inbound Rules

| Type | Port | Source    |
| ---- | ---- | --------- |
| HTTP | 80   | 0.0.0.0/0 |

Later we will also add:

* HTTPS 443

---

# Step 2 — Update Private EC2 Security Group

Currently:

* App SG only allows SSH

Now add:

| Type       | Port | Source    |
| ---------- | ---- | --------- |
| Custom TCP | 8000 | sp-alb-sg |

---

# Why Port 8000?

Because Gunicorn application is running on:

```bash id="alb-3"
0.0.0.0:8000
```

---

# Step 3 — Create Target Group

Go to:

```text id="alb-4"
EC2 → Target Groups → Create
```

Choose:

| Setting     | Value     |
| ----------- | --------- |
| Target type | Instances |
| Protocol    | HTTP      |
| Port        | 8000      |
| VPC         | sp-vpc    |

---

# Step 4 — Configure Health Check

Health check path:

```text id="alb-5"
/login
```

---

# What is Health Check?

ALB periodically checks:

👉 “Is application alive?”

If unhealthy:

* ALB stops sending traffic

---

# Step 5 — Register Targets

Select:

```text id="alb-6"
sp-private-app
```

Click:

```text id="alb-7"
Include as pending below
```

Then:

```text id="alb-8"
Create target group
```

---

# Step 6 — Create ALB

Go to:

```text id="alb-9"
EC2 → Load Balancers → Create Load Balancer
```

Choose:

```text id="alb-10"
Application Load Balancer
```

---

# Step 7 — Configure ALB

Fill:

| Setting | Value           |
| ------- | --------------- |
| Name    | sp-alb          |
| Scheme  | Internet-facing |
| IP Type | IPv4            |

---

# Step 8 — Select Network

Choose:

| Setting | Value                   |
| ------- | ----------------------- |
| VPC     | sp-vpc                  |
| Subnets | sp-public1 + sp-public2 |

---

# Why Public Subnets?

Because ALB must receive internet traffic.

---

# Step 9 — Attach Security Group

Attach:

```text id="alb-11"
sp-alb-sg
```

---

# Step 10 — Attach Target Group

Select:

```text id="alb-12"
sp-tg
```

---

# Step 11 — Create ALB

Click:

```text id="alb-13"
Create Load Balancer
```

---

# Step 12 — Wait for Health Check

Go to:

```text id="alb-14"
Target Groups → Targets
```

Wait until:

```text id="alb-15"
Healthy
```

---

# IMPORTANT ISSUE YOU FACED

Initially:

❌ Target unhealthy

---

# Root Cause

App security group did not allow:

```text id="alb-16"
8000 from ALB SG
```

---

# Fix

Added inbound rule:

| Port | Source    |
| ---- | --------- |
| 8000 | sp-alb-sg |

---

# Step 13 — Test Application

Go to:

```text id="alb-17"
EC2 → Load Balancer → DNS Name
```

Copy ALB DNS.

Open in browser:

```text id="alb-18"
http://<ALB-DNS>
```

✅ Application worked successfully

---

# Part 16 — Route53 Domain Setup

Currently users access app using:

❌ Long ALB DNS name

Now we will use:

✅ Real domain

Example:

```text id="r53-1"
https://infralabx.space
```

---

# What is Route53?

AWS DNS service.

DNS converts:

```text id="r53-2"
infralabx.space
```

into:

```text id="r53-3"
ALB IP address
```

---

# Step 1 — Create Hosted Zone

Go to:

```text id="r53-4"
Route53 → Hosted Zones → Create
```

Enter:

```text id="r53-5"
infralabx.space
```

---

# Step 2 — Copy Name Servers

AWS gives 4 NS records.

Example:

```text id="r53-6"
ns-xxx.awsdns.com
```

---

# Step 3 — Update Domain Registrar

Go to your domain provider.

Replace nameservers with Route53 nameservers.

---

# Why?

This tells internet:

👉 “AWS manages my domain now”

---

# Step 4 — Create A Record

Inside hosted zone:

```text id="r53-7"
Create Record
```

Choose:

| Setting     | Value  |
| ----------- | ------ |
| Record Type | A      |
| Alias       | YES    |
| Target      | sp-alb |

---

# Result

Now:

```text id="r53-8"
infralabx.space
```

points to:

```text id="r53-9"
ALB
```

---

# Part 17 — HTTPS using ACM

Currently site uses:

❌ HTTP

Now we enable:

✅ HTTPS

---

# What is ACM?

AWS Certificate Manager

Used for:

* SSL certificates
* HTTPS encryption

---

# Step 1 — Request Certificate

Go to:

```text id="acm-1"
AWS Certificate Manager → Request
```

Choose:

```text id="acm-2"
Public certificate
```

---

# Step 2 — Add Domain

Enter:

```text id="acm-3"
infralabx.space
```

---

# Step 3 — DNS Validation

Choose:

```text id="acm-4"
DNS validation
```

---

# Step 4 — Create Validation Records

AWS gives CNAME record.

Click:

```text id="acm-5"
Create records in Route53
```

---

# Step 5 — Wait for Validation

Status changes:

```text id="acm-6"
Pending Validation → Issued
```

---

# Step 6 — Add HTTPS Listener to ALB

Go to:

```text id="acm-7"
ALB → Listeners → Add Listener
```

Choose:

| Setting  | Value |
| -------- | ----- |
| Protocol | HTTPS |
| Port     | 443   |

Attach ACM certificate.

Forward to:

```text id="acm-8"
sp-tg
```

---

# IMPORTANT ISSUE YOU FACED

HTTPS did not work initially.

---

# Root Cause

ALB Security Group did not allow:

```text id="acm-9"
443
```

---

# Fix

Added inbound rule:

| Type  | Port | Source    |
| ----- | ---- | --------- |
| HTTPS | 443  | 0.0.0.0/0 |

---

# Step 7 — Final Test

Open:

```text id="acm-10"
https://infralabx.space
```

✅ HTTPS working

---

# Part 18 — Upload Application to S3

Now we prepare app for Auto Scaling.

---

# Why Upload to S3?

Future EC2 instances need application code automatically.

---

# Step 1 — Zip Project

On local machine:

```bash id="s3-1"
zip -r InfraProjects.zip InfraProjects
```

---

# What does this do?

| Part              | Meaning            |
| ----------------- | ------------------ |
| zip               | Compress files     |
| -r                | Recursive          |
| InfraProjects.zip | Output file        |
| InfraProjects     | Folder to compress |

---

# Step 2 — Upload to S3

```bash id="s3-2"
aws s3 cp InfraProjects.zip s3://infra-projects-dmp/
```

---

# Command Explanation

| Part              | Meaning         |
| ----------------- | --------------- |
| aws s3 cp         | Copy file to S3 |
| InfraProjects.zip | Local file      |
| s3://             | S3 bucket path  |

---
