# Part 19 — Launch Template (Automatic Server Blueprint)

At this point:

✅ Application works using ALB
✅ HTTPS working
✅ Domain working
✅ RDS connected

But currently:

❌ Application exists only inside one manually created EC2 instance.

If instance dies:

* Application goes down

Now we solve this using:

✅ Launch Template
✅ Auto Scaling Group (ASG)

---

# What is Launch Template?

Launch Template = Blueprint for EC2 instances.

It tells AWS:

* Which OS to use
* Which security group
* Which IAM role
* Which startup script to run
* Which application to install

---

# What is user_data?

user_data = Script that automatically runs when EC2 starts.

Instead of manually:

* installing packages
* cloning repo
* starting app

AWS will do everything automatically.

---

# Final Goal

Whenever ASG creates new EC2:

✅ App automatically installs
✅ App automatically starts
✅ App automatically connects to RDS

---

# Step 1 — Create Launch Template

Go to:

```text id="lt-1"
EC2 → Launch Templates → Create launch template
```

---

# Step 2 — Basic Details

Enter:

| Field                | Value                |
| -------------------- | -------------------- |
| Launch template name | sp-app-lt            |
| Description          | Student app template |

---

# Step 3 — AMI

Choose:

```text id="lt-2"
Amazon Linux 2023
```

---

# Step 4 — Instance Type

Choose:

```text id="lt-3"
t3.micro
```

---

# Step 5 — Key Pair

You can skip.

---

# Why Skip?

Because now we use:

✅ SSM Session Manager

instead of SSH.

---

# Step 6 — Network Settings

Do NOT choose subnet.

---

# Why?

Because ASG will later decide:

* which subnet
* which AZ

---

# Step 7 — Security Group

Attach:

```text id="lt-4"
sp-private-sg
```

---

# Step 8 — IAM Role

Attach IAM role containing:

* AmazonSSMManagedInstanceCore
* AmazonS3ReadOnlyAccess

---

# Why?

| Permission | Purpose          |
| ---------- | ---------------- |
| SSM        | Remote access    |
| S3         | Download app zip |

---

# Step 9 — Add user_data Script

Scroll down:

```text id="lt-5"
Advanced Details → User Data
```

Paste:

```bash id="lt-6"
#!/bin/bash
set -e

# Save logs
exec > /var/log/user-data.log 2>&1

# Install packages
dnf install -y git python3-pip unzip awscli

# Move to home directory
cd /home/ec2-user

# Download project from S3
aws s3 cp s3://infra-projects-dmp/InfraProjects.zip .

# Unzip project
unzip InfraProjects.zip

# Move into application folder
cd InfraProjects/StudentProfileApp

# Create Python virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate

# Install dependencies
pip install --break-system-packages -r requirements.txt

# Set RDS connection string
export DB_LINK="postgresql://postgres:password@RDS-ENDPOINT:5432/mydb"

# Start application
nohup .venv/bin/gunicorn -b 0.0.0.0:8000 run:app > /var/log/app.log 2>&1 &
```

---

# IMPORTANT — Line-by-Line Explanation

---

# 1. Bash Script Start

```bash id="lt-exp-1"
#!/bin/bash
```

👉 Tells Linux:
“Run this using bash shell”

---

# 2. Stop on Error

```bash id="lt-exp-2"
set -e
```

👉 If any command fails:

* script stops immediately

---

# 3. Save Logs

```bash id="lt-exp-3"
exec > /var/log/user-data.log 2>&1
```

👉 Saves all logs into:

```text id="lt-exp-4"
/var/log/user-data.log
```

Useful for debugging.

---

# 4. Install Packages

```bash id="lt-exp-5"
dnf install -y git python3-pip unzip awscli
```

---

## Package Explanation

| Package     | Purpose                  |
| ----------- | ------------------------ |
| git         | Manage code              |
| python3-pip | Install Python libraries |
| unzip       | Extract zip              |
| awscli      | Access S3                |

---

# 5. Move to Home Directory

```bash id="lt-exp-6"
cd /home/ec2-user
```

---

# 6. Download App from S3

```bash id="lt-exp-7"
aws s3 cp s3://infra-projects-dmp/InfraProjects.zip .
```

---

## Explanation

| Part      | Meaning           |
| --------- | ----------------- |
| aws s3 cp | Copy from S3      |
| s3://     | S3 path           |
| .         | Current directory |

---

# 7. Unzip Project

```bash id="lt-exp-8"
unzip InfraProjects.zip
```

---

# 8. Move into App Folder

```bash id="lt-exp-9"
cd InfraProjects/StudentProfileApp
```

---

# 9. Create Virtual Environment

```bash id="lt-exp-10"
python3 -m venv .venv
```

---

# Why Virtual Environment?

Keeps Python packages isolated.

---

# 10. Activate Virtual Environment

```bash id="lt-exp-11"
source .venv/bin/activate
```

---

# 11. Install Dependencies

```bash id="lt-exp-12"
pip install --break-system-packages -r requirements.txt
```

---

# 12. Set Database Connection

```bash id="lt-exp-13"
export DB_LINK="postgresql://..."
```

---

# Why?

Application needs:

* DB username
* DB password
* RDS endpoint

to connect to database.

---

# 13. Start Application

```bash id="lt-exp-14"
nohup .venv/bin/gunicorn -b 0.0.0.0:8000 run:app &
```

---

# Explanation

| Part     | Meaning                   |
| -------- | ------------------------- |
| nohup    | Keep running after logout |
| gunicorn | Python app server         |
| -b       | Bind                      |
| 0.0.0.0  | Accept traffic            |
| 8000     | App port                  |
| &        | Run in background         |

---

# Step 10 — Create Launch Template

Click:

```text id="lt-7"
Create launch template
```

---

# Part 20 — Test Launch Template

Before creating ASG:

✅ We first tested Launch Template manually.

---

# Step 1 — Launch Instance from Template

Go to:

```text id="test-lt-1"
Launch Templates → Actions → Launch instance from template
```

---

# Step 2 — Select Private Subnet

Choose:

```text id="test-lt-2"
sp-private1
```

---

# IMPORTANT ISSUE YOU FACED

Initially:
❌ Application did not start

---

# Root Cause

Private EC2 had:
❌ No internet access

So:

* could not install packages
* could not download from S3

---

# Fix

You temporarily:
✅ Re-added NAT Gateway

---

# Why NAT Was Needed?

Because user_data script required internet for:

* package installation
* S3 access

---

# Step 3 — Verify user_data Logs

SSM into instance:

```bash id="test-lt-3"
aws ssm start-session --target <INSTANCE_ID>
```

Check logs:

```bash id="test-lt-4"
cat /var/log/user-data.log
```

---

# Step 4 — Verify Application Logs

```bash id="test-lt-5"
cat /var/log/app.log
```

---

# Expected Output

```text id="test-lt-6"
Starting gunicorn
Listening at: http://0.0.0.0:8000
```

---

# Step 5 — Verify Process Running

```bash id="test-lt-7"
ps -ef | grep gunicorn
```

---

# What does ps -ef do?

Shows running Linux processes.

---

# Step 6 — Verify Locally

```bash id="test-lt-8"
curl localhost:8000
```

---

# Expected Output

Application HTML or redirect response.

---

# Result

✅ Launch Template successfully creates working application servers automatically.

---
