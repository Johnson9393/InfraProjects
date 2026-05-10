# Assignment

## Student Profile Application — Production Infrastructure Setup

This assignment demonstrates building a production-style AWS infrastructure to deploy the **Student Profile (SP) application** using a secure, scalable, and private architecture.

The setup includes:

* Custom VPC
* Public & private subnets across multiple AZs
* Bastion host access
* Private EC2 for application
* IAM roles (no static credentials inside EC2)
* VPC Endpoints (removing NAT dependency)
* Secure access using SSM Session Manager

---

## Part 1 — VPC Setup

### Create VPC

* Navigate to VPC → Create VPC
* Select **VPC only**

Configuration:

* Name: `sp-vpc`
* CIDR block: `10.0.0.0/16`

This creates the base network for the application.

---

### Create Subnets

Create the following subnets:

| Name            | AZ         | CIDR        | Purpose             |
| --------------- | ---------- | ----------- | ------------------- |
| sp-public1      | us-east-1a | 10.0.1.0/24 | Bastion / Public    |
| sp-public2      | us-east-1b | 10.0.2.0/24 | NAT / Future LB     |
| sp-private1     | us-east-1a | 10.0.3.0/24 | Application servers |
| sp-private2     | us-east-1b | 10.0.4.0/24 | Application servers |
| sp-private-rds1 | us-east-1a | 10.0.5.0/24 | Database subnet     |
| sp-private-rds2 | us-east-1b | 10.0.6.0/24 | Database subnet     |

---

### Internet Gateway

* Create Internet Gateway: `sp-igw`
* Attach to `sp-vpc`

This enables internet connectivity for public subnets.

---

### Public Route Table

* Create route table: `sp-public-rt`
* Associate:

  * sp-public1
  * sp-public2

Add route:

```id="r1"
0.0.0.0/0 → Internet Gateway (sp-igw)
```

---

## Part 2 — Bastion Host

### Launch Bastion EC2

* Name: `bastion`
* AMI: Amazon Linux
* Instance type: t3.micro
* Subnet: sp-public1
* Public IP: Enabled

---

### Bastion Security Group

Inbound:

| Type | Port | Source                |
| ---- | ---- | --------------------- |
| SSH  | 22   | 0.0.0.0/0 (temporary) |

---

### SSH into Bastion

```bash id="r2"
chmod 400 bootcamp-key.pem
ssh -i bootcamp-key.pem ec2-user@<BASTION_PUBLIC_IP>
```

---

## Part 3 — Private Application EC2

### Launch Private Instance

* Name: `sp-private-app`
* Subnet: sp-private1
* Public IP: Disabled

---

### Security Group (sp-private-sg)

Inbound:

| Type | Port | Source     |
| ---- | ---- | ---------- |
| SSH  | 22   | bastion-sg |

---

### Access via Bastion

```bash id="r3"
scp -i bootcamp-key.pem bootcamp-key.pem ec2-user@<BASTION_IP>:/home/ec2-user/

ssh -i bootcamp-key.pem ec2-user@<BASTION_IP>
chmod 400 bootcamp-key.pem

ssh -i bootcamp-key.pem ec2-user@<PRIVATE_IP>
```

---

### Test Internet (Expected Failure)

```bash id="r4"
sudo yum update -y
```

Fails because private subnet has no internet route.

---

## Part 4 — NAT Gateway Setup

### Create NAT Gateway

* Name: `sp-natgw`
* Subnet: sp-public2
* Allocate Elastic IP

---

### Private Route Table

* Create route table: `sp-private-rt`
* Associate:

  * sp-private1
  * sp-private2

Add route:

```id="r5"
0.0.0.0/0 → NAT Gateway (sp-natgw)
```

---

### Re-test Internet

```bash id="r6"
sudo yum update -y
```

Now works successfully.

---

## Part 5 — IAM Role for EC2

### Create IAM Role

* Use case: EC2

Attach policies:

* AmazonS3ReadOnlyAccess
* AmazonSSMManagedInstanceCore

---

### Attach Role to Instances

Attach role to:

* bastion
* sp-private-app

---

### Test S3 Access

```bash id="r7"
aws s3 ls
aws s3 ls s3://<your-bucket>
```

---

## Part 6 — Replace NAT with VPC Endpoint

### Delete NAT Gateway

* Delete `sp-natgw`
* Release Elastic IP

---

### Create S3 Gateway Endpoint

* Service: S3
* Type: Gateway
* Attach to route table: `sp-private-rt`

---

### Verify Access

```bash id="r8"
aws s3 ls s3://<your-bucket>
```

Works without NAT.

---

## Part 7 — SSM Session Manager Setup

### Enable VPC DNS

* Enable DNS resolution
* Enable DNS hostnames

---

### Create Interface Endpoints

Create 3 endpoints:

* com.amazonaws.us-east-1.ssm
* com.amazonaws.us-east-1.ssmmessages
* com.amazonaws.us-east-1.ec2messages

---

### Endpoint Configuration

* Attach to:

  * sp-private1
  * sp-private2
* Security group: `vpce-sg`

---

### Endpoint Security Group (vpce-sg)

Inbound rule:

| Type  | Port | Source        |
| ----- | ---- | ------------- |
| HTTPS | 443  | sp-private-sg |

---

### Important Behavior

* No inbound rules required on EC2
* EC2 initiates outbound connection to SSM

---

## Part 8 — AWS CLI Setup

### Install CLI

```bash id="r9"
brew install awscli
```

---

### Configure CLI

```bash id="r10"
aws configure
```

Provide:

* Access key
* Secret key
* Region: us-east-1
* Output: json

---

### Verify CLI

```bash id="r11"
aws sts get-caller-identity
```

---

## Part 9 — SSM Access (No SSH Required)

### Install Session Manager Plugin

```bash id="r12"
brew install --cask session-manager-plugin
```

---

### Start Session

```bash id="r13"
aws ssm start-session \
--target <INSTANCE_ID> \
--region us-east-1
```

---

### Result

* Connected to private EC2
* No SSH keys used
* No bastion required
* No open ports required

---

## Architecture Summary

```id="r14"
Internet → sp-igw → sp-public subnets → bastion
                             ↓
                      sp-private subnets → sp-private-app
                             ↓
                  VPC Endpoints → AWS Services (SSM, S3)
```

---

## Key Learnings

* Designed custom VPC with proper subnet segmentation
* Implemented bastion-based secure access
* Understood NAT Gateway vs VPC Endpoint
* Used IAM roles instead of static credentials
* Eliminated SSH using SSM Session Manager
* Built secure private infrastructure for application deployment

---

