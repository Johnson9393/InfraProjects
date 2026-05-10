# Part 10 — Application Setup Inside Private EC2

At this point:

✅ You already created:

* VPC
* Private EC2
* SSM access

Now we will:

* Install Python
* Clone application
* Run application manually

---

# Step 1 — Connect Using SSM

Go to terminal on your laptop:

```bash id="p10-1"
aws ssm start-session \
--target <INSTANCE_ID> \
--region us-east-1
```

---

# Step 2 — Install Required Packages

Inside EC2:

```bash id="p10-2"
sudo dnf install -y git python3-pip postgresql-server
```

---

## What does this command do?

| Package           | Purpose                   |
| ----------------- | ------------------------- |
| git               | Download code from GitHub |
| python3-pip       | Install Python libraries  |
| postgresql-server | PostgreSQL database       |

---

# Step 3 — Clone GitHub Repository

```bash id="p10-3"
git clone https://github.com/JohnsonQA/InfraProjects
```

---

## What is git clone?

👉 Downloads your GitHub project into EC2.

---

# Step 4 — Move Into Application Folder

```bash id="p10-4"
cd InfraProjects/StudentProfileApp
```

---

# Step 5 — Create Python Virtual Environment

```bash id="p10-5"
python3 -m venv .venv
```

---

## Why Virtual Environment?

👉 Keeps project libraries isolated.

Without this:

* Different projects may break each other.

---

# Step 6 — Activate Virtual Environment

```bash id="p10-6"
source .venv/bin/activate
```

---

## Expected Output

You will now see:

```bash id="p10-7"
(.venv)
```

👉 Means virtual environment is active.

---

# Step 7 — Install Python Dependencies

```bash id="p10-8"
pip install -r requirements.txt
```

---

## What is requirements.txt?

👉 File containing all Python libraries needed by app.

---

# Part 11 — Local PostgreSQL Database Setup

Initially we used:

✅ PostgreSQL inside EC2

Later we migrated to:

✅ RDS (production database)

---

# Step 1 — Initialize PostgreSQL

```bash id="p11-1"
sudo postgresql-setup --initdb
```

---

## What does initdb do?

👉 Creates initial PostgreSQL database structure.

---

# Step 2 — Start PostgreSQL

```bash id="p11-2"
sudo systemctl start postgresql
```

---

## What is systemctl?

👉 Linux service manager.

Used to:

* start services
* stop services
* restart services

---

# Step 3 — Login to PostgreSQL

```bash id="p11-3"
sudo -u postgres psql
```

---

## Command Explanation

| Part             | Meaning                      |
| ---------------- | ---------------------------- |
| sudo -u postgres | Run command as postgres user |
| psql             | PostgreSQL shell             |

---

# Step 4 — Create Database

Inside PostgreSQL shell:

```sql id="p11-4"
CREATE DATABASE mydb;
```

Exit:

```sql id="p11-5"
\q
```

---

# Step 5 — Run Application

Inside project folder:

```bash id="p11-6"
gunicorn -b 0.0.0.0:8000 run:app
```

---

## Command Explanation

| Part     | Meaning                            |
| -------- | ---------------------------------- |
| gunicorn | Python production web server       |
| -b       | Bind                               |
| 0.0.0.0  | Accept traffic from all interfaces |
| 8000     | Application port                   |
| run:app  | Flask app object                   |

---

# Step 6 — Verify App

Inside EC2:

```bash id="p11-7"
curl localhost:8000
```

---

## What is curl?

👉 Sends HTTP request from terminal.

---

# Step 7 — Add Sample Data

Open application in browser.

Add:

* students
* classes
* attendance

This creates real database records.

---

# Part 12 — Backup Local Database

Before migrating to RDS, we first took backup.

---

# Step 1 — Take Backup

```bash id="p12-1"
pg_dump -Fc postgresql://localhost:5432/mydb -f /tmp/mydb_final.dump
```

---

## Command Explanation

| Part      | Meaning                  |
| --------- | ------------------------ |
| pg_dump   | Export PostgreSQL DB     |
| -Fc       | Custom compressed format |
| localhost | Local DB                 |
| mydb      | Database name            |
| -f        | Output file              |

---

# Step 2 — Verify Backup File

```bash id="p12-2"
ls -lh /tmp/mydb_final.dump
```

---

# Part 13 — RDS (Production Database)

Now we move from local database → managed AWS database.

---

# Why RDS?

| Local PostgreSQL     | RDS               |
| -------------------- | ----------------- |
| Manual maintenance   | AWS managed       |
| Risky                | Highly available  |
| No automatic backups | Automated backups |
| Single server        | Multi-AZ capable  |

---

# Step 1 — Create RDS Subnet Group

Go to:

```text id="p13-1"
RDS → Subnet groups → Create
```

Add:

* sp-rds1
* sp-rds2

---

# Why Separate DB Subnets?

👉 Keeps database isolated from application servers.

---

# Step 2 — Create RDS

Go to:

```text id="p13-2"
RDS → Create database
```

Choose:

| Setting       | Value            |
| ------------- | ---------------- |
| Engine        | PostgreSQL       |
| Template      | Free tier        |
| DB Name       | mydb             |
| Username      | postgres         |
| Public Access | No               |
| VPC           | sp-vpc           |
| Subnet Group  | RDS subnet group |

---

# Step 3 — Security Group for RDS

Allow:

| Type       | Port | Source        |
| ---------- | ---- | ------------- |
| PostgreSQL | 5432 | sp-private-sg |

---

## Why?

👉 Only application servers should access DB.

---

# Step 4 — Copy RDS Endpoint

Go to:

```text id="p13-3"
RDS → Connectivity & security
```

Copy:

```text id="p13-4"
sp-rds-db.xxxxx.us-east-1.rds.amazonaws.com
```

---

# Step 5 — Export Database Connection String

Inside EC2:

```bash id="p13-5"
export RDS_DB_LINK='postgresql://postgres:password@sp-rds-db.xxxxx.us-east-1.rds.amazonaws.com:5432/mydb'
```

---

## IMPORTANT ISSUE YOU FACED

This failed initially:

```bash id="p13-6"
-bash: !123: event not found
```

---

## Why?

👉 Bash treats `!` as history expansion.

---

## Fix

Use:

✅ Single quotes `'...'`

instead of:

❌ Double quotes `"..."`

---

# Step 6 — Restore Backup into RDS

```bash id="p13-7"
pg_restore -Fc -d "$RDS_DB_LINK" /tmp/mydb_final.dump
```

---

# Step 7 — Verify Migration

```bash id="p13-8"
psql "$RDS_DB_LINK" -c "\dt"
```

---

## Verify Data

```bash id="p13-9"
psql "$RDS_DB_LINK" -c "SELECT count(*) FROM student;"
```

---

# Part 14 — systemd Service (Auto Start App)

Earlier:

* App runs manually
* Stops after logout/reboot

Now:

* App runs automatically

---

# Step 1 — Create Service File

```bash id="p14-1"
sudo vi /etc/systemd/system/sp-app.service
```

---

# Step 2 — Add Configuration

Paste:

```ini id="p14-2"
[Unit]
Description=Student Profile App (Gunicorn)
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/InfraProjects/StudentProfileApp

Environment="PATH=/home/ec2-user/InfraProjects/StudentProfileApp/.venv/bin"
Environment="DB_LINK=postgresql://postgres:password@RDS-ENDPOINT:5432/mydb"

ExecStart=/home/ec2-user/InfraProjects/StudentProfileApp/.venv/bin/gunicorn \
--workers 3 \
--bind 0.0.0.0:8000 \
run:app

Restart=always

[Install]
WantedBy=multi-user.target
```

---

# Step 3 — Start Service

```bash id="p14-3"
sudo systemctl daemon-reload
sudo systemctl enable sp-app
sudo systemctl restart sp-app
```

---

# Step 4 — Verify Service

```bash id="p14-4"
sudo systemctl status sp-app
```

---

# IMPORTANT ISSUE YOU FACED

Application showed:

❌ 500 Internal Server Error

---

# Root Cause

Inside service file:

```ini
Environment="DB_LINK=....""
```

Extra:

```text
"
```

at end caused issue.

---

# Fix

Removed extra quote.

Restarted service:

```bash id="p14-5"
sudo systemctl restart sp-app
```

Application worked.

---
