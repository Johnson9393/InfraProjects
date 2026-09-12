# Application Infrastructure — Terraform

## Purpose

The `app-infra` folder contains the AWS resources required by the application layer. Keeping this separate from `eks-core-infra` allows the EKS platform to be created independently and the application dependencies to be managed separately. The outcome of this phase is a private PostgreSQL RDS database, dedicated RDS networking, security controls, encryption, and secure database credentials ready to be consumed by the application running in EKS. :contentReference[oaicite:0]{index=0}

## What We Created

The application infrastructure uses Terraform variables and environment-specific values so the same configuration can be reused for environments such as `dev`, `stage`, and `prod`. The configuration is driven through the environment `.tfvars` files rather than hardcoding environment-specific values in the resources. :contentReference[oaicite:1]{index=1}

### Network / RDS Subnets

The existing VPC created by the core infrastructure is reused. Additional private subnets are created specifically for the database layer.

For the current environment:

    RDS Subnet 1 → 10.0.5.0/24 → us-east-1a
    RDS Subnet 2 → 10.0.6.0/24 → us-east-1b

These are private database subnets, so the RDS instance is not publicly accessible. The purpose is to keep the database inside the VPC and allow application workloads inside the private network to communicate with it. :contentReference[oaicite:2]{index=2}

The RDS subnet group uses these subnets so AWS knows where the RDS instance can be placed.

### RDS PostgreSQL

We created a PostgreSQL RDS instance:

    Identifier       → dojo-dev-rds
    Database         → dojo_db
    Engine           → PostgreSQL
    Engine Version   → 17.5
    Instance Class   → db.t3.medium
    Storage          → 30 GB GP3
    Max Storage      → 50 GB
    Port             → 5432
    Public Access    → Disabled

The important design decision is:

    publicly_accessible = false

This keeps the database private. The backend application running inside EKS will communicate with RDS through the VPC instead of exposing PostgreSQL directly to the internet.

The RDS instance is also configured with:

    Backup retention       → 7 days
    Storage encryption     → enabled
    Automated backups      → deleted with the instance
    Final snapshot         → skipped for this learning environment

### RDS Security Group

A dedicated Security Group was created for RDS:

    dojo-dev-rds-sg

Its purpose is to control who can connect to PostgreSQL.

The database listens on:

    TCP 5432

During implementation we initially used the wrong Terraform argument:

    security_groups = ["0.0.0.0/0"]

`security_groups` expects Security Group IDs, while `0.0.0.0/0` is a CIDR range. The rule was corrected to use:

    cidr_blocks = ["0.0.0.0/0"]

For this learning setup, this allows PostgreSQL traffic on port 5432. In a production design, this should be restricted to the EKS/backend Security Group.

The intended production flow is:

    Backend Pod
        ↓
    EKS Node / Pod networking
        ↓
    RDS Security Group
        ↓
    PostgreSQL :5432
        ↓
    RDS

### KMS Encryption

A dedicated AWS KMS key is created for RDS encryption.

The RDS configuration uses the KMS key ARN:

    kms_key_id = aws_kms_key.rds_kms.arn

The distinction is important:

    aws_kms_key.rds_kms.id
        → KMS key ID

    aws_kms_key.rds_kms.arn
        → Full KMS ARN

RDS expects the KMS key ARN in this configuration.

A KMS alias is also created so the key can be referenced with a meaningful name instead of only its generated key ID.

### Secrets Manager

Database credentials are not hardcoded into the application.

Terraform generates the database password using `random_password` and stores the database credentials in AWS Secrets Manager. This provides centralized secret storage and avoids putting the actual password directly into application configuration. :contentReference[oaicite:3]{index=3}

The secret created for the current environment is:

    dojo-dev-rds-secrets

The basic flow is:

    Terraform
        ↓
    Generate database credentials
        ↓
    AWS Secrets Manager
        ↓
    Application
        ↓
    DATABASE_URL
        ↓
    PostgreSQL RDS

The database connection information is generated dynamically so the backend can connect to the correct database endpoint for the environment. :contentReference[oaicite:4]{index=4}

### Secret Version

The `aws_secretsmanager_secret` resource creates the secret container, while `aws_secretsmanager_secret_version` stores the actual secret value.

This separation is useful because the secret itself and its individual versions are managed independently.

The secret value is marked sensitive by Terraform and is not intended to be displayed as normal output.

## Dependency Flow

Terraform creates the application infrastructure in dependency order:

    Existing VPC
        ↓
    RDS Private Subnets
        ↓
    RDS Subnet Group
        ↓
    RDS Security Group
        ↓
    KMS Key
        ↓
    Secrets Manager
        ↓
    PostgreSQL RDS
        ↓
    RDS Endpoint
        ↓
    Backend Application

The important application connectivity is:

    EKS Backend
          ↓
    VPC Networking
          ↓
    RDS Security Group :5432
          ↓
    Private RDS
          ↓
    PostgreSQL

## Terraform Workflow Used

Before applying infrastructure changes:

    terraform fmt -recursive

Validate the configuration:

    terraform validate

Initialize Terraform with the environment-specific backend:

    terraform init \
      -backend-config=vars/dev.tfbackend \
      -reconfigure

Create the execution plan:

    terraform plan \
      -var-file=vars/dev.tfvars

Apply the infrastructure:

    terraform apply \
      -var-file=vars/dev.tfvars

When the environment is no longer required:

    terraform destroy \
      -var-file=vars/dev.tfvars

This workflow keeps the Terraform state in the configured remote backend and uses the environment-specific variable file for the deployment. :contentReference[oaicite:5]{index=5}

## Important Troubleshooting Learned

During this deployment we encountered two Terraform issues.

### 1. CIDR vs Security Group ID

Wrong:

    security_groups = ["0.0.0.0/0"]

Correct for a CIDR rule:

    cidr_blocks = ["0.0.0.0/0"]

Remember:

    security_groups → sg-xxxxxxxx
    cidr_blocks     → 10.0.0.0/16 / 0.0.0.0/0

### 2. KMS ID vs KMS ARN

Wrong:

    kms_key_id = aws_kms_key.rds_kms.id

Correct:

    kms_key_id = aws_kms_key.rds_kms.arn

When AWS requires an ARN, use `.arn`, not `.id`.

### 3. Tainted Terraform Resource

The RDS Security Group was created successfully, but a later rule configuration failed. Terraform therefore marked the resource as `tainted`.

Terraform then attempted to replace it, but AWS already had the Security Group with the same name.

We verified the existing AWS resource, removed only the Terraform state reference, and imported the existing Security Group again:

    terraform state rm aws_security_group.dojo_rds_sg

    terraform import \
      aws_security_group.dojo_rds_sg \
      sg-00ad884539affe481

Then:

    terraform plan

The final plan showed:

    2 to add
    1 to change
    0 to destroy

Therefore Terraform updated the existing Security Group and created the remaining resources without destroying the existing infrastructure.

Important:

    terraform state rm
        → removes only Terraform's state reference
        → does NOT delete the AWS resource

    terraform import
        → connects an existing AWS resource to Terraform state

## Final Outcome

The application infrastructure now provides:

    Existing EKS VPC
          ↓
    Dedicated RDS Private Subnets
          ↓
    RDS Subnet Group
          ↓
    RDS Security Group
          ↓
    KMS Encryption
          ↓
    PostgreSQL RDS
          ↓
    Secrets Manager Credentials
          ↓
    Ready for Backend Application

The EKS core infrastructure provides the platform, while this application infrastructure provides the database and its supporting AWS resources.

The next application phase can therefore focus on Kubernetes resources such as Namespace, ConfigMap, Secret, Deployment, Service, probes, requests/limits, and connecting the backend Pod to this RDS instance.