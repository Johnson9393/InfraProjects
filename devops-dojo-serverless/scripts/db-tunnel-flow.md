# Database Tunnel (SSM)

This script creates a secure tunnel from your local machine to the private RDS database using **AWS Systems Manager (SSM)** through the Bastion Host.

No SSH, no PEM key and no public RDS access are required.

---

## Folder Structure

```
scripts/
├── db-tunnel.sh
└── README.md
```

---

## Prerequisites

- AWS CLI installed
- AWS Session Manager Plugin installed
- AWS SSO configured
- Bastion EC2 is running
- RDS is running
- Bastion IAM Role has `AmazonSSMManagedInstanceCore`
- Bastion Security Group is allowed to access RDS on port **5432**

---

## Script Usage

```
bash scripts/db-tunnel.sh -e <environment> -p <local_port>
```

Example:

```
bash scripts/db-tunnel.sh -e dev -p 65001
```

Future:

```
bash scripts/db-tunnel.sh -e prod -p 65001
```

---

## Parameters

### Environment

```
-e
```

Specifies the deployment environment.

Examples:

```
dev
prod
qa
preprod
```

---

### Local Port

```
-p
```

Specifies the local port on your laptop.

Example:

```
65001
```

The script forwards

```
localhost:<local_port>
```

to

```
RDS:5432
```

---

## Daily Workflow

### Step 1

Login using AWS SSO

```
aws sso login --profile <Profile_Name>
```

---

### Step 2

Export AWS Profile

```
export AWS_PROFILE=<Profile_Name>
```

Verify:

```
echo $AWS_PROFILE
```

---

### Step 3

Start Database Tunnel

```
bash scripts/db-tunnel.sh -e dev -p 65001
```

Keep this terminal open.

---

### Step 4

Open DBeaver

Connection:

```
Host       : localhost
Port       : 65001
Database   : <database_name>
Username   : <db_username>
Password   : <db_password>
```

---

## Script Flow

### 1. Validate Input

Validates:

- Environment
- Local Port
- AWS_PROFILE

---

### 2. Find Bastion Host

Uses AWS CLI to discover the running Bastion EC2 instance.

No Instance ID is hardcoded.

---

### 3. Find RDS Endpoint

Uses AWS CLI to retrieve the RDS endpoint for the selected environment.

No endpoint is hardcoded.

---

### 4. Start SSM Port Forwarding

Creates an encrypted tunnel:

```
Local Machine
      │
      ▼
localhost:65001
      │
      ▼
AWS Session Manager
      │
      ▼
Bastion EC2
      │
      ▼
Private RDS:5432
```

The tunnel remains active until the terminal is closed or **Ctrl + C** is pressed.

---

## Stop Tunnel

Press

```
Ctrl + C
```

---

## Common Commands

AWS Profiles

```
aws configure list-profiles
```

Current Profile

```
echo $AWS_PROFILE
```

Verify Login

```
aws sts get-caller-identity
```

Check Running Bastion

```
aws ec2 describe-instances
```

Check RDS

```
aws rds describe-db-instances
```

---

## Notes

- Never expose the RDS publicly.
- Keep the database in private subnets.
- Use SSM instead of SSH.
- Keep the tunnel terminal open while using DBeaver.
- Close the tunnel after completing your work.
