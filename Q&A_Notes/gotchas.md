# gotchas.md

# 1. Private EC2 Had No Internet Access

## Problem

Inside private EC2:

```bash id="v1d5pm"
dnf install
git clone
pip install
```

were failing.

---

## Root Cause

Private subnet had no outbound internet route.

No NAT Gateway attached.

---

## Solution We Did

Created:

```text id="p3r9za"
NAT Gateway
```

inside public subnet.

Attached Elastic IP.

Updated private route table:

```text id="y8x4lt"
0.0.0.0/0 → NAT Gateway
```

---

# 2. user_data Script Was Stuck

## Problem

Log stopped at:

```text id="k7t4wc"
Cloning into 'InfraProjects'...
```

Looked like script hung.

---

## Command We Used

```bash id="b2q6xm"
cat /var/log/user-data.log
```

---

## Root Cause

Git clone and package installation were taking time.

---

## Solution We Did

Waited few minutes and rechecked logs.

Verified repo existed:

```bash id="g1r8sv"
cd
ls
```

Output:

```text id="d4n7pj"
InfraProjects
InfraProjects.zip
```

---

# 3. pip Install Failed in Amazon Linux 2023

## Problem

```bash id="f9t3vw"
pip3 install -r requirements.txt
```

failed.

---

## Root Cause

Amazon Linux 2023 blocks system package modification.

---

## Solution We Did

Used:

```bash id="x2m5cz"
pip3 install --break-system-packages -r requirements.txt
```

Later improved using virtual environment.

---

# 4. Virtual Environment Missing

## Problem

Dependencies were installing globally.

Not production standard.

---

## Solution We Did

Created virtual environment:

```bash id="r8v4lt"
python3 -m venv .venv
```

Activated:

```bash id="q6z1fb"
source .venv/bin/activate
```

Installed dependencies:

```bash id="m9p7ys"
pip install --break-system-packages -r requirements.txt
```

---

# 5. App Was Running Manually But Not Automatically

## Problem

Application worked manually after SSH login but failed from Launch Template.

---

## Root Cause

`run.sh` behaved differently inside cloud-init.

---

## Solution We Did

Directly started Gunicorn in user_data:

```bash id="u3n8rh"
nohup .venv/bin/gunicorn -b 0.0.0.0:8000 run:app > /var/log/app.log 2>&1 &
```

---

# 6. Gunicorn Verification

## Command We Used

```bash id="v5m1pk"
ps -ef | grep gunicorn
```

---

## Successful Output

```text id="t8c6wy"
gunicorn -b 0.0.0.0:8000 run:app
```

---

# 7. Verified Application Locally

## Command We Used

```bash id="k2q9vb"
curl localhost:8000
```

---

## Successful Output

```text id="f1z7tx"
Redirecting to /login
```

Meaning:

* Gunicorn working
* Flask app working

---

# 8. ALB Health Check Failed Initially

## Problem

Target Group showed:

```text id="w4n8ks"
Unhealthy
```

---

## Root Cause

Health check path:

```text id="a9t3mf"
/
```

returned redirect.

---

## Solution We Did

Changed Target Group health check path to:

```text id="j6x1yr"
/login
```

Then targets became healthy.

---

# 9. ASG Stayed in “Updating Capacity”

## Problem

ASG showed:

```text id="e7r2lu"
Updating Capacity
```

---

## Root Cause

EC2 needed time to:

* launch
* run user_data
* install packages
* start app
* pass health check

---

## Solution We Did

Verified from instance:

```bash id="p5s8gw"
cat /var/log/user-data.log
```

and:

```bash id="n2m6zc"
cat /var/log/app.log
```

Waited until Target Group became healthy.

---

# 10. pg_dump Command Not Found

## Problem

```bash id="b9x4qh"
pg_dump: command not found
```

---

## Root Cause

PostgreSQL client tools missing.

---

## Solution We Did

Installed PostgreSQL 17 client:

```bash id="w6f2rk"
sudo dnf install -y postgresql17
```

---

# 11. RDS Backup Failed

## Problem

```bash id="q3y8tp"
connection to server on socket failed
```

---

## Root Cause

Environment variable:

```bash id="u7l4mv"
$RDS_DB_LINK
```

was empty.

---

## Command We Used

Checked variable:

```bash id="o1d9ks"
echo $RDS_DB_LINK
```

Output was empty.

---

## Solution We Did

Exported properly:

```bash id="r4t7xy"
export RDS_DB_LINK='postgresql://postgres:PASSWORD@RDS-ENDPOINT:5432/mydb'
```

Used single quotes because password contained:

```text id="m8v3pw"
!
```

---

# 12. First Backup File Was Empty

## Problem

Backup file size:

```text id="z5n2qx"
0 bytes
```

---

## Root Cause

Previous DB connection failed.

---

## Solution We Did

Retried dump command:

```bash id="k7w1sf"
pg_dump -Fc "$RDS_DB_LINK" -f /tmp/rds_backup_$(date +%F_%H-%M).dump
```

Verified:

```bash id="y3p8lt"
ls -lh /tmp
```

---

# 13. Uploaded Backup to S3

## Command We Used

```bash id="v8r4mz"
aws s3 cp /tmp/rds_backup_2026-05-09_18-53.dump s3://infra-projects-dmp/backups/
```

---

# Purpose

Stored database backup safely in S3.

---

# 14. SSM Session Manager Not Working Initially

## Problem

Instances not visible in Session Manager.

---

## Root Cause

Missing:

* IAM role
* VPC endpoints
* outbound connectivity

---

## Solution We Did

Attached IAM policy:

```text id="q9m2dw"
AmazonSSMManagedInstanceCore
```

Created VPC Endpoints:

* SSM
* EC2Messages
* SSMMessages

---

# 15. SCP Command Failed Initially

## Problem

Used wrong SCP syntax:

```bash id="p1v6kn"
scp -i InfraProjects.zip ec2-user@10.x.x.x:/home/ec2-user
```

---

## Root Cause

`.zip` mistakenly used as SSH key.

---

## Solution We Did

Instead of SCP:

* uploaded project zip to S3

Used:

```bash id="l7r5zx"
aws s3 cp s3://infra-projects-dmp/InfraProjects.zip .
```

inside user_data.

---

# 16. ALB Elastic IP Confusion

## Problem

Elastic IP showed:

```text id="j4t9ys"
Service Managed : alb
```

---

## Root Cause

ALB internally manages AWS-owned IPs.

---

## Solution We Did

Understood:

* Route53 should point to ALB DNS
* not fixed Elastic IP

---

# 17. HTTPS Not Working Initially

## Problem

Domain opened only with HTTP.

---

## Solution We Did

Created:

* ACM SSL certificate
* HTTPS Listener : 443
* Route53 Alias Record

Configured:

```text id="f6w2qm"
HTTP → HTTPS redirect
```

---

# 18. Launch Template Testing Was Important

## Problem

Debugging directly through ASG was difficult.

---

## Root Cause

ASG keeps replacing unhealthy instances automatically.

---

## Solution We Did

First tested Launch Template manually:

```text id="x8q3rb"
Launch instance from template
```

Verified:

* logs
* app
* health checks

Then created ASG.

---

# 19. Bastion Became Unnecessary

## Problem

Initially architecture depended on SSH + Bastion.

---

## Solution We Did

Moved fully to:

```text id="c2y7mv"
AWS Systems Manager (SSM)
```

Deleted:

* bastion EC2
* old private EC2

App still worked through ASG.

---

# Final Learning

```text id="n5u8zp"
Most real DevOps issues are infrastructure problems:
networking, IAM, routing, health checks,
environment variables, package dependencies,
and startup automation.
```
