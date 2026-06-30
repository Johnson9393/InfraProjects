# Deployment Pipeline Design Decisions

## Overview

While building the CI/CD pipeline for this project, I intentionally documented every design decision instead of only documenting the final implementation.

This document explains:

- The initial deployment design
- Problems discovered during testing
- Why those problems occurred
- How the pipeline was redesigned
- Key GitHub Actions concepts learned during implementation

---

# Initial Pipeline Design

Initially, my deployment pipeline looked like this:

```text
Build & Push Images
        │
        ▼
Database Migration
        │
        ▼
Deploy Backend
        │
        ▼
Deploy Frontend
```

At first glance this looked correct.

However, while testing the deployment, I discovered a major issue.

---

# Problem

The migration job was executing using the **currently deployed ECS Task Definition**, not the newly built Docker image.

The migration step looked like this:

```yaml
--task-definition dojo-dev-backend
```

Although a new image had already been pushed to Amazon ECR, ECS still referenced the latest ACTIVE task definition.

Therefore the migration always executed using the old application version.

---

# Why This Is Dangerous

Imagine the following scenario.

Current deployment:

```text
Backend v1
Database Schema v1
```

Developer pushes:

```text
Backend v2
New Alembic Migration
```

Old pipeline:

```text
Build Image

↓

Run Migration (v1)

↓

Deploy Backend (v2)
```

The migration never contains the latest database changes because it executes inside the previous container image.

This can easily cause runtime failures.

---

# Root Cause

The ECS Task Definition is only a blueprint.

Simply pushing a new Docker image to Amazon ECR **does not** update the ECS Task Definition.

Until a new revision is created, ECS continues using the previous Task Definition revision.

---

# Solution

To solve this problem I introduced a new job:

```text
Prepare Backend Task Definition
```

The new pipeline became:

```text
Build Images
        │
        ▼
Prepare Backend Task Definition
        │
        ▼
Run Database Migration
        │
        ▼
Deploy Backend
        │
        ▼
Deploy Frontend
```

This guarantees the migration runs using the same container image that will later be deployed.

---

# Preparing the Task Definition

The workflow first downloads the current Task Definition.

```yaml
aws ecs describe-task-definition \
  --task-definition dojo-dev-backend \
  --query taskDefinition \
  > task-definition.json
```

This exports the current ECS Task Definition into a JSON file.

---

# Updating the Container Image

Only the image field is modified.

```yaml
jq '.containerDefinitions[0].image = "ECR_REPOSITORY:${{ github.sha }}"'
```

This replaces the old container image with the image built in the current GitHub Actions workflow.

---

# Why jq?

Instead of manually editing JSON, jq allows programmatic updates.

Example:

Before:

```json
image: backend:latest
```

After:

```json
image: backend:9f8d7ab
```

This guarantees every deployment references the exact Git commit.

---

# Why Remove AWS Generated Fields?

Before registering a new Task Definition, AWS-generated metadata must be removed.

```yaml
del(
  .taskDefinitionArn,
  .revision,
  .status,
  .registeredAt,
  .registeredBy,
  .compatibilities,
  .requiresAttributes
)
```

These values are generated automatically by ECS.

Attempting to register them again causes AWS to reject the request.

---

# Registering a New Task Definition

After updating the image, a new revision is registered.

```yaml
aws ecs register-task-definition \
  --cli-input-json file://task-definition-updated.json
```

This creates a brand-new Task Definition revision.

For example:

```text
Revision 12

↓

Revision 13
```

Migration will now execute using Revision 13.

---

# Why Not Use the GitHub ECS Deploy Action?

Initially I considered using:

```yaml
uses: aws-actions/amazon-ecs-deploy-task-definition@v2
```

This action automatically:

- Registers a new Task Definition
- Updates the ECS Service
- Waits for deployment

Internally it behaves like:

```text
Register Task Definition

↓

Deploy ECS Service
```

However, I needed:

```text
Register Task Definition

↓

Run Database Migration

↓

Deploy ECS Service
```

The GitHub Action does not allow stopping after registration.

Therefore I used the AWS CLI for Task Definition registration.

---

# Passing Data Between Jobs

GitHub Actions runs every job on a different runner.

Variables cannot be shared directly.

Instead I used Job Outputs.

Inside the registration step:

```yaml
echo "task_definition_arn=$TASK_DEF" >> $GITHUB_OUTPUT
```

This creates a Step Output.

The job then exposes it:

```yaml
outputs:
  task_definition_arn: ${{ steps.register.outputs.task_definition_arn }}
```

Another job can access it using:

```yaml
${{ needs.prepare-task-definition.outputs.task_definition_arn }}
```

This guarantees migration always uses the exact Task Definition revision created earlier.

---

# Final Deployment Flow

```text
Developer Push
       │
       ▼
Build Backend Image
       │
Build Frontend Image
       │
       ▼
Push Images to Amazon ECR
       │
       ▼
Prepare Backend Task Definition
       │
       ▼
Register New Revision
       │
       ▼
Run Database Migration
       │
       ▼
Deploy Backend Service
       │
       ▼
Deploy Frontend Service
```

---

# Key Learnings

During this implementation I learned:

- ECS Task Definitions are only blueprints.
- Pushing a Docker image does not update ECS automatically.
- Database migrations should execute using the same application version that will be deployed.
- GitHub Job Outputs are required to share values between jobs.
- AWS CLI provides finer control over deployment sequencing than the built-in deployment action.
- Understanding deployment orchestration is more important than simply writing GitHub Actions YAML.