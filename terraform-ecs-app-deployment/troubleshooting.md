```hcl
# On Terraform apply got these errors

╷
│ Error: creating IAM Role (ecsTaskExecutionRole): operation error IAM: CreateRole, https response error StatusCode: 409, RequestID: e21b423d-8264-49f6-a6f7-08f0598ec694, EntityAlreadyExists: Role with name ecsTaskExecutionRole already exists.
│ 
│   with aws_iam_role.ecs_task_execution_role,
│   on iam.tf line 2, in resource "aws_iam_role" "ecs_task_execution_role":
│    2: resource "aws_iam_role" "ecs_task_execution_role" {
│ 
╵
╷
│ Error: creating RDS DB Instance (sp-rds-instance): operation error RDS: CreateDBInstance, https response error StatusCode: 400, RequestID: 5eb4629e-68cf-45e6-88ef-983b130f8684, api error InvalidParameterValue: DBName must begin with a letter and contain only alphanumeric characters.
│ 
│   with aws_db_instance.sp_rds_instance,
│   on rds.tf line 20, in resource "aws_db_instance" "sp_rds_instance":
│   20: resource "aws_db_instance" "sp_rds_instance" {
│ 
```

# RCA:
* Fixed above issues by deleting existing role that created manually
* updated db name with no hypens, underscores and spaces

---

# Issue 2 
```hcl
╷
│ Error: creating ECS Task Definition (sp-task-def): operation error ECS: RegisterTaskDefinition, https response error StatusCode: 400, RequestID: 50eac92a-a863-4bc1-80cd-21f7cb05c6e9, ClientException: No Fargate configuration exists for given values: 1024 CPU, 1024 memory. See the Amazon ECS documentation for the valid values.
│ 
│   with aws_ecs_task_definition.sp_task_definition,
│   on ecs.tf line 12, in resource "aws_ecs_task_definition" "sp_task_definition":
│   12: resource "aws_ecs_task_definition" "sp_task_definition" {
│ 
╵
```

* Fixed by updating memory size to 2048. Reason for 1 cpu 1024, cannot be paired with 1024 memory. valid combinations are as below
```
    cpu = 1024

    memory = 2048
    memory = 3072
    memory = 4096
    memory = 5120
    memory = 6144
    memory = 7168
    memory = 8192
```
----


# Succesfully Deployed an app and below are the snippets attached

![alt text](screenshots/AlbHealthStatus.png)
![alt text](screenshots/AppHealthStatus.png)

----

# Issue 3:
While registering got 500 Internal Server error

## Troubleshooting Steps:
* Check the cloud watch logs 
* Log details
![alt text](screenshots/ErrorLogs.png)

* Error says - DB schema is not created as DB initilaization code is the main block in run.py which dont exceute with gunicorn. Hence updated the code with `db.create_all()` in _init_.py file in `app.app_context()` function block

---


## 1. Missing `requires_compatibilities` in ECS Task Definition

### Error

When creating the ECS task definition for Fargate, the task failed to register or the ECS service could not launch tasks correctly.

### Cause

The task definition was missing:

```hcl
requires_compatibilities = ["FARGATE"]
```

Without this setting, ECS does not know that the task is intended to run on AWS Fargate.

### Fix

Added the following to the task definition:

```hcl
requires_compatibilities = ["FARGATE"]
network_mode             = "awsvpc"
```

After updating the task definition and applying Terraform, the ECS task registered successfully.

---

## 2. ECS Execution Role Missing Secrets Manager Permission

### Error

The ECS task failed to start and was unable to retrieve secrets configured in the task definition. ECS reported resource initialization errors when attempting to fetch secrets from AWS Secrets Manager.

### Cause

The ECS task execution role only had permissions to pull container images from ECR and write logs to CloudWatch. It did not have permission to read the database secret stored in AWS Secrets Manager.

### Fix

Added the following permission to the ECS execution role policy:

```hcl
{
  Effect = "Allow"
  Action = [
    "secretsmanager:GetSecretValue"
  ]
  Resource = aws_secretsmanager_secret.sp_db_secret.arn
}
```

After updating the IAM policy, ECS was able to retrieve the secret and start the container successfully.

---

## 3. ALB Target Group Using Default `instance` Target Type

### Error

The ECS service continuously failed health checks and targets were not registered correctly with the Application Load Balancer.

### Cause

The target group was created using the default target type:

```hcl
target_type = "instance"
```

AWS Fargate tasks do not run on EC2 instances. Each task receives its own Elastic Network Interface (ENI) and IP address.

### Fix

Changed the target group configuration to:

```hcl
target_type = "ip"
```

This allows the Application Load Balancer to register the IP addresses of Fargate tasks directly.

### What `target_type = "ip"` Means

The load balancer routes traffic directly to the private IP addresses of ECS Fargate tasks. This is required for Fargate because there are no EC2 instances available for the load balancer to target.

After updating the target group and redeploying the service, the targets became healthy and traffic was routed successfully.

---

# Failures when apply terraform from cicd pipeline

```hcl
╷
│ Error: creating Secrets Manager Secret (sp-rds-secret): operation error Secrets Manager: CreateSecret, https response error StatusCode: 400, RequestID: fa44995d-2dbf-44d0-945b-cff28cb5c872, InvalidRequestException: You can't create this secret because a secret with this name is already scheduled for deletion.
│ 
│   with aws_secretsmanager_secret.sp_rds_secret,
│   on rds.tf line 41, in resource "aws_secretsmanager_secret" "sp_rds_secret":
│   41: resource "aws_secretsmanager_secret" "sp_rds_secret" {
│ 
╵
Error: Terraform exited with code 1.
Error: Process completed with exit code 1.
```
# RCA: Terraform Apply Failed for AWS Secrets Manager Secret

## Root Cause

During Terraform deployment, creation of the AWS Secrets Manager secret `sp-rds-secret` failed with the following error:

```text
InvalidRequestException: You can't create this secret because a secret with this name is already scheduled for deletion.
```

Investigation was performed using:

```bash
aws secretsmanager describe-secret \
  --secret-id sp-rds-secret \
  --region us-east-1
```

The output confirmed that the secret already existed and was in a **Pending Deletion** state, as indicated by the presence of the `DeletedDate` attribute:

```json
{
  "Name": "sp-rds-secret",
  "DeletedDate": "2026-06-10T20:52:46.186000+05:30"
}
```

AWS reserves the secret name until the scheduled deletion is completed, preventing Terraform from creating a new secret with the same name.

## Resolution

1. Verified the secret status using `describe-secret` and confirmed the presence of `DeletedDate`.
2. Restored the secret from the Pending Deletion state:

```bash
aws secretsmanager restore-secret \
  --secret-id sp-rds-secret \
  --region us-east-1
```

3. Re-ran the Terraform deployment:

```bash
terraform apply
```

It failed again cause since we restored the secrets terraform state is not updated and it still holds the existing secrets which is in `pending for deletion`. 

## Quick Fix:

Forcefully deleted the secrets using below command

```hcl
aws secretsmanager delete-secret \
  --secret-id sp-rds-secret \
  --force-delete-without-recovery \
  --region us-east-1
```

Also, updated the terraform code in secrets manager creation with `recovery_window_in_days = 0` Hence forth, terraform will force immediate deletion instead of scheduling deletion upon terraform destroy

> Note: To verify changes are applid expected in state then run the following command `terraform state show aws_secretsmanager_secret.sp_rds_secret`
---

# Troubleshooting Log

## 1. Terraform Pipeline Succeeded but No Infrastructure Created

### Root Cause

The GitHub Actions workflow had a typo in the condition:

```yaml
if: inputs.plan_or_apply_or_destroy == 'apply' || inputs.plan_or_apply_or_destroy == 'destroy'
```

Input variable was actually:

```yaml
plan_or_apply_destroy
```

### Fix

```yaml
if: inputs.plan_or_apply_destroy == 'apply' || inputs.plan_or_apply_destroy == 'destroy'
```

---

## 2. Secrets Manager Secret Already Scheduled for Deletion

### Error

```text
InvalidRequestException:
You can't create this secret because a secret with this name is already scheduled for deletion.
```

### Root Cause

Terraform destroy scheduled the secret for deletion and AWS reserved the secret name.

### Verification

```bash
aws secretsmanager describe-secret \
  --secret-id sp-rds-secret \
  --region us-east-1
```

Output contained:

```json
"DeletedDate": "..."
```

### Fix

Force delete the secret:

```bash
aws secretsmanager delete-secret \
  --secret-id sp-rds-secret \
  --force-delete-without-recovery \
  --region us-east-1
```

Verify deletion:

```bash
aws secretsmanager describe-secret \
  --secret-id sp-rds-secret \
  --region us-east-1
```

Expected:

```text
ResourceNotFoundException
```

### Preventive Fix

```hcl
resource "aws_secretsmanager_secret" "sp_rds_secret" {
  name                    = "sp-rds-secret"
  recovery_window_in_days = 0
}
```

---

## 3. ECS Task Failed to Start

### Error

```text
CannotPullContainerError:
student-portal:latest not found
```

### Root Cause

Task definition referenced an image tag that did not exist in ECR.

### Fix

Run Build & Deploy pipeline to push image:

```bash
docker buildx build \
  --platform linux/amd64 \
  --push \
  -t <ecr-repo>:${GITHUB_SHA} \
  -t <ecr-repo>:latest .
```

Verify image exists in ECR.

---

## 4. GitHub Actions jq Syntax Error

### Error

```text
unexpected EOF while looking for matching `'`
```

### Root Cause

Invalid jq command syntax.

### Fix

```yaml
- name: Update Task Definition
  run: |
    jq --arg IMAGE "${{ env.ECR_REPO }}:${{ env.ECR_TAG }}" \
      '.containerDefinitions[0].image = $IMAGE' \
      task-definition.json > task-definition-updated.json
```

---

## 5. ECS Container Crash - ModuleNotFoundError

### Error

```text
ModuleNotFoundError: No module named 'app'
```

### Root Cause

Application package was renamed from:

```text
app/
```

to:

```text
src/
```

but imports were not updated.

### Fixes

#### run.py

```python
from src import create_app, db
```

#### src/**init**.py

```python
from src.logging_config import setup_logging
from src.metrics import http_requests_total, request_duration_seconds
from src.routes import routes, auth
```

#### src/models/models.py

```python
from src import db, login_manager
```

#### src/routes/auth.py

```python
from src.models.models import User, db
from src.metrics import auth_attempts
```

#### src/routes/routes.py

```python
from src.models.models import Student, Attendance, db, Class, Assignment, Announcement
from src.metrics import (
```

### Validation

Find remaining invalid imports:

```bash
grep -R "from app" .
grep -R "import app" .
```

Expected:

```text
(no output)
```

---

## 6. ECS Deployment Validation

### Verify ECS Task

```text
ECS → Cluster → Service → Tasks
```

Expected:

```text
Running = 1
Pending = 0
Desired = 1
```

### Verify Application

* Login page accessible
* User authentication working
* Sanity testing completed

---

## Final Status

```text
Terraform Apply              ✅
Secrets Manager             ✅
RDS                         ✅
ECR Image Push              ✅
ECS Deployment              ✅
ALB Routing                 ✅
Application Login           ✅
Sanity Testing              ✅
```
---



