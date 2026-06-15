# AWS Multi-Account Setup Using AWS Organizations and IAM Identity Center

## Objective

Replicate an enterprise-style AWS environment similar to my company's setup where:

- One AWS Management Account owns the organization.
- Multiple AWS Accounts exist for different environments.
- IAM Identity Center (AWS SSO) provides centralized login.
- A single SSO user can access multiple AWS accounts.
- Different permission sets (Admin, ReadOnly) can be assigned per account.

---

# Target Architecture

```text
Management Account
│
├── DEV Account
│   ├── AdministratorAccess
│   └── ReadOnlyAccess
│
└── PROD Account
    ├── AdministratorAccess
    └── ReadOnlyAccess

IAM Identity Center
│
└── User: Johnson0309
```

After setup, the AWS Access Portal should look similar to:

```text
DEV
 ├── AdministratorAccess
 └── ReadOnlyAccess

PROD
 ├── AdministratorAccess
 └── ReadOnlyAccess
```

---

# Prerequisites

## Existing Setup

I already have:

### Root AWS Account

```text
johnson.johnn3939@gmail.com
```

### IAM Identity Center User

```text
Johnson0309
```

### IAM Identity Center Enabled

I can already log in through:

```text
https://<my-sso-portal>.awsapps.com/start
```

---

# Step 1 - Verify IAM Identity Center

Login as Root User.

Navigate to:

```text
IAM Identity Center
```

Verify:

- User Johnson0309 exists.
- IAM Identity Center is enabled.

---

# Step 2 - Create AWS Organization

Navigate to:

```text
AWS Organizations
```

Click:

```text
Create Organization
```

Select:

```text
Enable all features
```

Result:

```text
Management Account
```

becomes the Organization Management Account.

---

# Step 3 - Create DEV AWS Account

Navigate to:

```text
AWS Organizations
→ Accounts
→ Add an AWS account
```

Choose:

```text
Create an AWS account
```

Provide:

```text
Account Name:
DEV

Email:
johnson+dev@gmail.com
```

Create account.

Wait for provisioning to complete.

---

# Step 4 - Create PROD AWS Account

Navigate to:

```text
AWS Organizations
→ Accounts
→ Add an AWS account
```

Provide:

```text
Account Name:
PROD

Email:
johnson+prod@gmail.com
```

Create account.

Result:

```text
Management Account
│
├── DEV
└── PROD
```

---

# Step 5 - Create Permission Sets

Navigate to:

```text
IAM Identity Center
→ Permission Sets
```

---

## Create AdministratorAccess Permission Set

Click:

```text
Create Permission Set
```

Choose:

```text
Predefined Permission Set
```

Select:

```text
AdministratorAccess
```

Name:

```text
AdministratorAccess
```

Create.

---

## Create ReadOnlyAccess Permission Set

Click:

```text
Create Permission Set
```

Select:

```text
ReadOnlyAccess
```

Name:

```text
ReadOnlyAccess
```

Create.

---

# Step 6 - Assign User to DEV Account

Navigate to:

```text
IAM Identity Center
→ AWS Accounts
```

Select:

```text
DEV
```

Click:

```text
Assign Users or Groups
```

Select:

```text
Johnson0309
```

Assign:

```text
AdministratorAccess
```

Complete assignment.

---

## Add ReadOnlyAccess to DEV

Repeat assignment.

Assign:

```text
ReadOnlyAccess
```

Result:

```text
DEV
 ├── AdministratorAccess
 └── ReadOnlyAccess
```

---

# Step 7 - Assign User to PROD Account

Navigate to:

```text
IAM Identity Center
→ AWS Accounts
```

Select:

```text
PROD
```

Assign:

```text
Johnson0309
```

Permission Set:

```text
AdministratorAccess
```

Complete.

---

## Add ReadOnlyAccess to PROD

Repeat assignment.

Assign:

```text
ReadOnlyAccess
```

Result:

```text
PROD
 ├── AdministratorAccess
 └── ReadOnlyAccess
```

---

# Step 8 - Verify Access Portal

Open:

```text
https://<my-sso-portal>.awsapps.com/start
```

Login:

```text
Johnson0309
```

Expected result:

```text
AWS Accounts

DEV
 ├── AdministratorAccess
 └── ReadOnlyAccess

PROD
 ├── AdministratorAccess
 └── ReadOnlyAccess
```

---

# Step 9 - Test Access

### DEV Administrator

Login using:

```text
DEV → AdministratorAccess
```

Verify:

- Create S3 bucket
- Create EC2
- Create SSM Parameter
- Create Secrets Manager Secret

---

### DEV ReadOnly

Login using:

```text
DEV → ReadOnlyAccess
```

Verify:

- Can view resources
- Cannot create resources

---

### PROD Administrator

Login using:

```text
PROD → AdministratorAccess
```

Verify full access.

---

### PROD ReadOnly

Login using:

```text
PROD → ReadOnlyAccess
```

Verify read-only permissions.

---

# Optional Enterprise Enhancements

After basic setup is working, implement:

## Organizational Units

```text
Root
│
├── NonProd
│   └── DEV
│
└── Prod
    └── PROD
```

---

## Service Control Policies (SCP)

Example:

- Block deletion of CloudTrail.
- Restrict specific AWS Regions.
- Restrict expensive services.

---

## Centralized Logging

Configure:

```text
CloudTrail Organization Trail
```

for all accounts.

---

## Terraform Practice

Deploy infrastructure from Management Account to:

```text
DEV
PROD
```

using cross-account IAM roles.

---

# Learning Outcomes

After completing this setup, I will gain hands-on experience with:

- AWS Organizations
- IAM Identity Center (AWS SSO)
- Permission Sets
- Multi-Account Architecture
- AWS Access Portal
- Cross-Account Access
- ReadOnly vs Admin Roles
- Enterprise AWS Account Management
- Terraform Multi-Account Deployments

This setup closely resembles the AWS account access model used in enterprise environments.