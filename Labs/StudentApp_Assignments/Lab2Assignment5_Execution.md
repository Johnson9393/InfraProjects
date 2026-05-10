# Part 21 — Auto Scaling Group (ASG)

At this point:

✅ Launch Template works
✅ New EC2 automatically installs app
✅ Application automatically starts

But currently:

❌ Only one EC2 exists

If that EC2 dies:

* app goes down

Now we solve this using:

✅ Auto Scaling Group (ASG)

---

# What is ASG?

ASG = Auto Scaling Group

It automatically:

* creates EC2 instances
* replaces failed instances
* scales up during traffic
* scales down when traffic reduces

---

# Real World Example

Suppose:

* one server crashes
* hardware fails
* instance accidentally deleted

Without ASG:

❌ Website goes down

With ASG:

✅ AWS automatically creates replacement server

---

# Final Architecture

```text id="asg-arch"
User
  ↓
ALB
  ↓
ASG
  ↓
Private EC2 Instances
  ↓
RDS
```

---

# Step 1 — Create Auto Scaling Group

Go to:

```text id="asg-1"
EC2 → Auto Scaling Groups → Create
```

---

# Step 2 — Name

Enter:

```text id="asg-2"
sp-asg
```

---

# Step 3 — Select Launch Template

Choose:

```text id="asg-3"
sp-app-lt
```

---

# Why?

ASG uses Launch Template blueprint to create EC2 instances automatically.

---

# Step 4 — Select VPC + Subnets

Choose:

| Setting | Value                     |
| ------- | ------------------------- |
| VPC     | sp-vpc                    |
| Subnets | sp-private1 + sp-private2 |

---

# Why Private Subnets?

Because:

* backend servers should not be public
* only ALB should expose application

---

# Step 5 — Attach Load Balancer

Choose:

```text id="asg-4"
Attach to existing load balancer
```

Select:

```text id="asg-5"
sp-tg
```

---

# Why Attach Target Group?

This allows:

✅ ALB → forward traffic to ASG instances

---

# Step 6 — Health Checks

Choose:

| Setting           | Value       |
| ----------------- | ----------- |
| Health Check Type | ELB         |
| Grace Period      | 300 seconds |

---

# What is Grace Period?

When EC2 starts:

* app needs time to install
* app needs time to boot

During this time:

* ALB should not mark instance unhealthy immediately

---

# Step 7 — Configure Capacity

Set:

| Setting | Value |
| ------- | ----- |
| Desired | 1     |
| Minimum | 1     |
| Maximum | 3     |

---

# Capacity Explanation

| Type    | Meaning               |
| ------- | --------------------- |
| Desired | Current EC2 count     |
| Minimum | Never go below this   |
| Maximum | Maximum scaling limit |

---

# Step 8 — Create ASG

Click:

```text id="asg-6"
Create Auto Scaling Group
```

---

# Step 9 — Wait for Instance Creation

Go to:

```text id="asg-7"
ASG → Instances
```

You will see:

✅ New EC2 instance launched automatically

---

# IMPORTANT THING YOU VERIFIED

You SSM connected into new ASG instance.

---

# Step 10 — Connect to ASG Instance

```bash id="asg-8"
aws ssm start-session --target <INSTANCE_ID>
```

---

# Step 11 — Verify Project Files

Inside EC2:

```bash id="asg-9"
cd
ls
```

Expected:

```text id="asg-10"
InfraProjects
InfraProjects.zip
```

---

# Why Was This Important?

It confirmed:

✅ user_data downloaded project from S3 successfully

---

# Step 12 — Verify Gunicorn Running

```bash id="asg-11"
ps -ef | grep gunicorn
```

---

# Expected Output

```text id="asg-12"
gunicorn -b 0.0.0.0:8000 run:app
```

---

# Why Was This Important?

It confirmed:

✅ Application automatically started successfully

---

# Step 13 — Verify Application Locally

```bash id="asg-13"
curl localhost:8000
```

---

# Expected Output

HTML redirect response.

---

# Why?

This confirmed:

✅ Application works inside EC2

---

# Step 14 — Verify Target Group Health

Go to:

```text id="asg-14"
EC2 → Target Groups → Targets
```

Expected:

```text id="asg-15"
Healthy
```

---

# What Does Healthy Mean?

ALB health checks succeeded.

ALB can now safely send user traffic.

---

# IMPORTANT RESULT

At this point:

✅ ALB working
✅ ASG working
✅ Automatic EC2 creation working
✅ App auto deployment working

---

# Part 22 — Delete Manual EC2 Instances

Earlier:

You manually created:

* bastion EC2
* old private EC2

Now:

ASG automatically creates instances.

So old servers are no longer needed.

---

# Why Delete Old EC2?

Because:

❌ Manual servers are not scalable
❌ Manual servers are not self-healing

ASG is now handling everything automatically.

---

# Step 1 — Delete Bastion

Go to:

```text id="cleanup-1"
EC2 → Instances
```

Terminate:

```text id="cleanup-2"
bastion
```

---

# Why Safe to Delete?

Because:

* SSM is now used
* no SSH needed

---

# Step 2 — Delete Old Manual App EC2

Terminate:

```text id="cleanup-3"
sp-private-app
```

---

# IMPORTANT TEST YOU DID

After deleting both instances:

✅ Application STILL worked

---

# Why?

Because ASG instance was now serving traffic automatically.

---

# Final Architecture Now

```text id="final-arch"
User
 ↓
Route53
 ↓
ALB (HTTPS)
 ↓
ASG
 ↓
Private EC2
 ↓
RDS
```

---

# Part 23 — Backup from ASG Instance

Now you wanted to take latest RDS backup.

---

# IMPORTANT ISSUE YOU FACED

Inside ASG EC2:

```bash id="backup-1"
pg_dump: command not found
```

---

# Why?

Because PostgreSQL client tools were not installed.

---

# Step 1 — Install PostgreSQL 17 Client

```bash id="backup-2"
sudo dnf install -y postgresql17
```

---

# Why PostgreSQL 17?

Because RDS version was:

```text id="backup-3"
PostgreSQL 17
```

Using wrong version causes:

* dump failures
* restore failures

---

# IMPORTANT ISSUE YOU FACED

Initially:

```bash id="backup-4"
export RDS_DB_LINK="postgresql://postgres:password..."
```

failed with:

```text id="backup-5"
event not found
```

---

# Root Cause

Password contained:

```text id="backup-6"
!
```

Bash treated it as history expansion.

---

# Fix

Use:

✅ Single quotes

```bash id="backup-7"
export RDS_DB_LINK='postgresql://postgres:password@RDS-ENDPOINT:5432/mydb'
```

---

# Step 2 — Take Backup

```bash id="backup-8"
pg_dump -Fc "$RDS_DB_LINK" -f /tmp/rds_backup_$(date +%F_%H-%M).dump
```

---

# Command Breakdown

| Part        | Meaning                  |
| ----------- | ------------------------ |
| pg_dump     | Export PostgreSQL DB     |
| -Fc         | Compressed custom format |
| $(date ...) | Dynamic timestamp        |
| -f          | Output file              |

---

# Step 3 — Verify Backup

```bash id="backup-9"
ls -lh /tmp
```

---

# Expected Output

```text id="backup-10"
rds_backup_2026-05-09_18-53.dump
```

---

# Step 4 — Upload Backup to S3

```bash id="backup-11"
aws s3 cp /tmp/rds_backup_2026-05-09_18-53.dump \
s3://infra-projects-dmp/backups/
```

---

# Result

✅ Database backup safely stored in S3

---

# FINAL RESULT OF ENTIRE PROJECT

Successfully built:

✅ Private backend architecture
✅ RDS managed database
✅ HTTPS secured application
✅ ALB load balancing
✅ Auto Scaling infrastructure
✅ Automatic app deployment
✅ Backup system
✅ Production-grade AWS architecture

---

# END
