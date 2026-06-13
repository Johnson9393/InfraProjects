# Terraform ECS App Deployment

This repository contains a production-style AWS infrastructure deployment project using Terraform and Amazon ECS Fargate.

The goal of this project is to deploy a containerized application on AWS using Infrastructure as Code (IaC) principles with Terraform.

---

# Current Folder Structure

```text id="v1m94h"
terraform-ecs-app-deployment/
├── about_me.yaml                  # warm-up
├── infra/
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── sg.tf
│   ├── rds.tf
│   ├── ecs.tf
│   ├── alb.tf
│   ├── route53.tf
│   ├── cloudwatch.tf
│   └── .gitignore
├── app/
│   └── src/                       # Your two-tier app code
├── .github/
│   └── workflows/
│       └── build-and-deploy.yml
└── README.md
```

---

# Project Goal

This project will include:

- AWS VPC Infrastructure
- ECS Fargate Deployment
- Application Load Balancer
- PostgreSQL RDS
- Route53 DNS
- ACM SSL Certificate
- Amazon ECR
- GitHub Actions CI/CD
- Terraform Remote Backend

---

# Application Setup

The application source code has been copied into:

```text id="dd6d95"
app/src/
```

Required application files such as:

- Dockerfile
- requirements.txt
- docker-compose.yml
- config.py
- run.py

have also been added to the `app/` directory.

---

# Rules for every submission

- Never commit .terraform/, _.tfstate, _.tfstate.backup, or .env files — add them to .gitignore before your first push
- Run terraform fmt before committing any .tf file
- Run terraform validate before running terraform plan
- Always terraform destroy after testing to avoid unnecessary AWS charges
- Write a short commit message that describes what you did (e.g. add nat gateway and private route table)
- — update the README as you go

---

# Task 1 - YAML warm-up

Create a file called about_me.yaml in the root of the repo. This file demonstrates the three core YAML concepts

## File must include:

- At least one dictionary (key-value pairs — name, city, role)
- At least one list (hobbies, tools you use, or skills)
- At least one nested structure (e.g. experience or education with sub-keys)

Validate the file with a YAML linter (yamllint or any online tool) before committing.

> **Why this matters:**
> While writing Github Actions workflows in YAML we will be comfortable with indentation and structure now will save a lot of debugging later.

---

# Task 2 — Install Terraform and tfenv

Install tfenv and use it to manage Terraform versions.

```bash
## Mac
brew install tfenv

## WSL / Linux
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

## Install and Activate Terraform Version
tfenv install 1.12.1
tfenv use 1.12.1
terraform version
```

---

## Checklist:

- ✅ tfenv installed and working
- ✅ Terraform 1.12.1 active
- ✅ `terraform version` shows 1.12.1

---

# Task 3 - Create versions.tf and initialize the project

Create the infra/ folder. Inside it, create versions.tf with the Terraform and AWS provider version constraints.

```bash
terraform {
  required_version = "= 1.12.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}
```

Run terraform init and confirm the .terraform/ folder and lock file are created.

Add the following to infra/.gitignore:

```text
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
.terraform.lock.hcl
```

> **Note:** `.terraform.lock.hcl` is committed to the repository to maintain consistent Terraform provider versions across different environments and team members.

---

# Task 4 - Build the full VPC using Terraform

## Resources to create:

- VPC with enable_dns_hostnames = true and enable_dns_support = true
- 2 public subnets across two availability zones
- 2 private subnets across two availability zones
- 2 database subnets (separate CIDR range — keep RDS isolated)
- Create IGW and attach to vpc to access internet from public
- EIP and NAT for Private subnets to access internet
- Create public route table with route to IGW and associate with public subnets
- Create private route table with route to NGW and associate with private subnets

## Reference Flow:

```text
Public subnets  → Public route table  → Internet Gateway  → Internet
Private subnets → Private route table → NAT Gateway → Internet
DB subnets      → No outbound route   → VPC-internal only
```

## Commands to validate and apply VPC on aws

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

---

## Task 5 - Create provider.tf

Created a `provider.tf` file to explicitly configure the AWS provider and apply default tags to all supported AWS resources.

### provider.tf

```hcl
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      managed_by = "terraform"
      project    = "bootcamp"
    }
  }
}
```

### Key Points

- Applied default tags (`managed_by = "terraform"` and `project = "bootcamp"`) to ensure consistent resource tagging across the infrastructure.
- In a real company these tags help you identify which repository owns which resource, especially when you have hundreds of resources across multiple teams.

---

# Task 6 - configure remote state in S3

Move state from local to s3

- Create an S3 bucket and enable the version
- Add the backend block in versions.tf

```hcl
terraform {
  backend "s3" {
    bucket       = "sp-state-bucket"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

- Run terraform init -migrate-state and confirm the state file appears in S3
- Run terraform state list and paste the output in your README as a code block
- To verify object in s3 use `terraform state pull`
- Image attached and can be check the output in image.png in the infra/ folder

![alt text](screenshots/image.png)

> **Note:** With versioning enabled on the bucket you can recover a deleted or corrupted state file. Always enable this.

---

# Task 7 - Create security group for ECS, ALB, RDS

Create sg.tf with 3 secuirty groups.

| Security Group | Inbound Rule         | Source                      |
| -------------- | -------------------- | --------------------------- |
| ALB SG         | Port 80 and 443      | `0.0.0.0/0` (public-facing) |
| ECS SG         | Port 8000 (app port) | ALB SG only                 |
| RDS SG         | Port 5432 (Postgres) | ECS SG only                 |

> This reflects the real traffic flow: Internet → ALB → ECS Task → RDS. Each layer only accepts traffic from the layer above it.

---

# Task 8 - Create RDS and secrets manager entry to store rds creds

Create rds.tf with:

- A random password using the random provider (alpha-numeric only — no special characters to avoid connection string issues)
- A DB subnet group using your database subnets
- A aws_db_instance resource (Postgres, db.t3.micro, single instance, no backup retention for cost saving)
- A aws_secretsmanager_secret and aws_secretsmanager_secret_version that stores the full DB connection string including username, password, host, port, and DB name

The secret string format should match what your app expects:

```
postgresql://username:password@host:5432/dbname
```

> **Note**: Use aws_db_instance outputs to build the connection string dynamically — do not hardcode the endpoint.

---

# Task 9 - Create ECS cluster, Task Definition and Service

Create ecs.tf with:

- Create a ECS cluster which is a logical unit that contains the ECS services and tasks.
- Before creating ECS Task definition, create a log group where app logs will write inside the log group and IAM role and policies to pull the ecr image and write the app logs
- Create cloudwatch.tf and create a resouce keeping rention days for 7 days
- Then create iam.tf with a resource IAM role for ecs execution task role which allows and assumes a service ecs-task
- Create iam policy that has permissions to pull ecr image and write logs in cloud watch and attach the policy to ecs task execution role

> **Note**: Secure the IAM policy with permissions to pull ecr image, write logs to a specific log group and permission to read secret manager to read secrets only

- Now create ecs task definition with
  - Fargate launch type
  - The DB connection string passed as a `secrets` reference (not plain `environment`) pointing to the Secrets Manager ARN
  - `requires_compatibilities = ["FARGATE"]`
  - `network_mode = "awsvpc"`
  - log configuartion
  - Execution role arn to be attached for ecs task def allows to pull image and write logs
  - port mapping with host and container
  - Image name

> Passing secrets via the secrets block instead of plain environment variables means the value is never visible in the ECS console task configuration. This is the correct production approach.

---

# Task 10 - Create ALB, Target Group and ECS Service

Create alb.tf with:

* An ALB in public subnets with the ALB SG
* A TG with target_type=ip (required for Fargate), health check on your app's login or health endpoint
* An HTTP listener on port 80 forwarding to the target group
* An ECS service in the private subnets, attached to the target group, with launch_type = "FARGATE"

Verify deployment 

```hcl
# After apply, get the ALB DNS name
terraform output alb_dns_name

# Hit the endpoint
curl http://<alb-dns-name>/
```
---

# Task 11 - Route 53 and ACM certificate

Create route53.tf with:

* A data block to reference your existing hosted zone (do not re-create it)
* A Route 53 A record aliased to the ALB for your subdomain (e.g. app.yourdomain.com)
* An ACM certificate for the same subdomain with DNS validation
* A for_each loop to create the DNS validation CNAME records automatically
* An HTTPS listener (port 443) on the ALB using the validated certificate

> Once deployed, confirm your app is reachable at https://app.yourdomain.com.

* Create the HTTPS listener in alb.tf and forward the tarffic to TG securely by acm cert

--- 

# Perform Terraform commands

```
terraform fmt
terraform validate
terraform plan
terraform apply -auto-destroy
```

> Once all the resources created, open the app and verify application working as expected or not. If any issues, troubleshoot and re-run the terraform apply

## Note: Updated the issues faced and rca details in troubleshooting.md file. Have a look at it

# Task 12 - Github Actions
Before creating actual build workflows practice a simple workflow 

Create .github/workflows/tes-workflow.yaml:

```yaml
# Practice workflow with multi runners, multi line commands and multi jobs
name: Test Workflow

on:
  #push:
  workflow_dispatch:

jobs:
  run-linux-comand:
    runs-on: ubuntu-latest
    steps:
      - name: Run  Linux command
        run: echo "Hello world! from Linux"
      
      - name: Run multi line Linux command
        run: |
          echo "This is a multi line command"
          echo "Hello world! from Linux"

  run-windows-command:
    runs-on: windows-latest
    steps:
      - name: Run Windows command
        run: echo "Hello world! from Windows"
  
  run-mac-command:
    needs: run-windows-command
    runs-on: macos-latest
    steps:
      - name: Run Mac command
        run: echo "Hello world! from Mac"
```

> Run the flow and verify the jobs are succesfully completed 

![alt text](screenshots/TestWorkflow.png)

---

# Task 13 - Create a pipeline that builds the app and push the image to the ECR repo

Create a workflow sp-build-and-deploy.yaml

```yaml
# This workflow builds the Student Portal app and pushes the image to ECR

name: app-build-deploy

on:
  push:
    # Only trigger the workflow when there is a change in the app directory
    branches:
      - main
    paths:
      - 'terraform-ecs-app-deployment/app/**'

  # Manual trigger for the workflow
  workflow_dispatch:

env:
  AWS_REGION: us-east-1
  ECR_REPO: 023192525105.dkr.ecr.us-east-1.amazonaws.com/student-portal
  ECR_TAG: ${{ github.sha }} # Use commit SHA to create unique image tags
  APP_PATH: terraform-ecs-app-deployment/app

jobs:
  build-and-push-image:
    # This job:
    # - Runs on a GitHub-hosted runner
    # - Builds the Docker image
    # - Authenticates to AWS ECR
    # - Pushes the image

    runs-on: ubuntu-latest

    steps:
      # Checkout the repository code
      - name: Checkout code
        uses: actions/checkout@v4

      # Set up Docker Buildx
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Configure AWS credentials
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      # Authenticate Docker to ECR
      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2

      # Build Docker image
      - name: Build image
        run: |
          cd ${{ env.APP_PATH }}
          docker build -t ${{ env.ECR_REPO }}:${{ env.ECR_TAG }} .

      # Push image to ECR
      - name: Push image to ECR
        run: |
          docker push ${{ env.ECR_REPO }}:${{ env.ECR_TAG }}

```

> **Note**: If ECR repo is not created, create using terraform inside infra folder before building the pipeline. 

- Terraform code to create ECR Repo

```hcl
# Create ECR repository to store the application Docker Image. 
resource "aws_ecr_repository" "sp_ecr_repo" {
    name = "sp-ecr-repo"
    image_tag_mutability = "IMMUTABLE"
}


output "ecr_repository_url" {
    value = aws_ecr_repository.sp_ecr_repo.repository_url
}
```
Apply this before building the CI/CD pipeline. Copy the repository URI — you will need it in the workflow.

> Set image_tag_mutability = "IMMUTABLE" so image tags cannot be overwritten. This is a security and auditability requirement in most production environments.

---

- Succesfully pushed the image to ECR repo

![alt text](screenshots/DockerImage.png)

![alt text](screenshots/BuildPipeline.png)

---

# Task 14 - Deploy the Image to ECS using github actions

Update the sp-build-and-deploy.yaml with:

```yaml
deploy-ecs-service:
    needs: build-and-push-image
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
    
    # Downlaod the Task definition
      - name: Download Task Definition
        run: |
          aws ecs describe-task-definition \
            --task-definition ${{ env.ECS_TASK_DEF }} \
            --region ${{ env.AWS_REGION }} \
            --query taskDefinition \
            > task-definition.json
    
    # Update Task Definition with the commit sha image that we have pushed to ECR
      - name: Update Task Definition
        run: |
          jq .containerDefinitions[0].image = "${{ env.ECR_REPO }}:${{ env.ECR_TAG }}"' \
            task-definition.json > task-definition-updated.json
      
    # Deploy to ECS 
      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: task-definition-updated.json
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
```

> Post images are pushed to ECR, then updating the task definition with the required image tag using json 

# Task 15 - Observe the rolling deployment

After pipeline runs succesfully:

1. Go to  ECS cluster → service → deployments tab
2. Take a screenhsot of old task draining and new task running
3. Check the ALB target group — confirm new tasks register as healthy before old ones are removed

![alt text](screenshots/RollingUpdate.png)

![alt text](screenshots/DockerImage.png)

![alt text](screenshots/Logs.png) 

![alt text](screenshots/ALBHealth.png) 

![alt text](screenshots/AppTest.png) 

---




