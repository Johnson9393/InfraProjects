# Terraform Reflection — RDS Security Group Issue

## What Happened

While creating the application infrastructure, the RDS Security Group failed because the ingress rule was initially configured incorrectly.

We used:

    security_groups = ["0.0.0.0/0"]

But `security_groups` expects an actual Security Group ID such as:

    sg-xxxxxxxxxxxxxxxxx

`0.0.0.0/0` is a CIDR block, so it must be used with `cidr_blocks`:

    cidr_blocks = ["0.0.0.0/0"]

The corrected RDS ingress rule allows PostgreSQL traffic on port 5432:

    ingress {
      from_port   = 5432
      to_port     = 5432
      protocol     = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

For the current learning setup this was used intentionally, but in a production design PostgreSQL should be restricted to the EKS/backend Security Group instead of allowing `0.0.0.0/0`.

## Why the Security Group Already Existed

During the first Terraform apply, AWS successfully created the Security Group before Terraform failed while configuring its rules.

Therefore:

    AWS
      ↓
    dojo-dev-rds-sg
      ↓
    sg-00ad884539affe481

The Security Group existed in AWS and Terraform also had it in its state.

We verified it with:

    aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=dojo-dev-rds-sg" \
                "Name=vpc-id,Values=vpc-020bc76359bd745e7" \
      --query "SecurityGroups[].{ID:GroupId,Name:GroupName}" \
      --output table

Result:

    dojo-dev-rds-sg
    sg-00ad884539affe481

## Why Terraform Tried to Recreate It

Because the previous operation failed, Terraform marked the Security Group as:

    tainted

A tainted resource means Terraform considers the resource unreliable after a failed operation and may try to replace it.

We confirmed this using:

    terraform state show aws_security_group.dojo_rds_sg

It showed:

    id = "sg-00ad884539affe481"

and:

    (tainted)

After fixing the Security Group rule, Terraform planned to destroy the tainted Security Group and create a replacement.

However, AWS rejected the replacement because the original Security Group with the same name was still present:

    InvalidGroup.Duplicate

So the problem was not that Terraform had created two Security Groups. The problem was that Terraform wanted to replace an existing AWS Security Group while that existing Security Group still existed.

## Why Import Initially Failed

We first tried:

    terraform import aws_security_group.dojo_rds_sg sg-00ad884539affe481

Terraform returned:

    Resource already managed by Terraform

This confirmed that Terraform already had the Security Group in its state.

Therefore, importing directly was not possible while the existing state entry was still present.

## Removing the Resource From Terraform State

We removed only the Terraform state reference:

    terraform state rm aws_security_group.dojo_rds_sg

Important: `terraform state rm` does NOT delete the AWS resource.

It only tells Terraform:

    "Stop tracking this resource in the current Terraform state."

After this:

    AWS
      ↓
    dojo-dev-rds-sg
    sg-00ad884539affe481

    Terraform State
      ↓
    Resource reference removed

The actual AWS Security Group remained untouched.

## Importing the Existing Security Group

We then connected the existing AWS Security Group back to the Terraform resource:

    terraform import aws_security_group.dojo_rds_sg sg-00ad884539affe481

This was successful.

Now Terraform state correctly represents the existing AWS resource:

    AWS Security Group
          ↓
    sg-00ad884539affe481
          ↕
    Terraform State
          ↕
    aws_security_group.dojo_rds_sg

## Final Plan

We ran:

    terraform plan

The final result was:

    Plan: 2 to add, 1 to change, 0 to destroy

This meant:

    2 to add
      → Create RDS
      → Create Secrets Manager secret version

    1 to change
      → Update the existing RDS Security Group

    0 to destroy
      → Nothing will be deleted

Terraform would therefore update the existing Security Group in place instead of trying to recreate it.

## Important Lessons

`security_groups` is for Security Group IDs:

    security_groups = ["sg-xxxxxxxx"]

`cidr_blocks` is for IP/CIDR ranges:

    cidr_blocks = ["0.0.0.0/0"]

`.id` and `.arn` are different:

    aws_kms_key.rds_kms.id
      → KMS key ID

    aws_kms_key.rds_kms.arn
      → KMS ARN

When a resource expects an ARN, use `.arn`.

A resource can exist in AWS while Terraform's state is incorrect, stale, or tainted. Always check both AWS and Terraform state before deleting anything.

Useful troubleshooting commands:

    aws ec2 describe-security-groups ...
    terraform state show <resource>
    terraform state rm <resource>
    terraform import <resource> <resource-id>
    terraform plan

## Troubleshooting Flow

    Terraform Apply
          ↓
    Operation fails
          ↓
    Check whether AWS resource was created
          ↓
    Check Terraform state
          ↓
    If resource is tainted, understand why
          ↓
    Check terraform plan
          ↓
    If replacement conflicts with an existing AWS resource
          ↓
    Remove only the incorrect state reference
          ↓
    Import the existing AWS resource
          ↓
    terraform plan
          ↓
    Verify 0 unexpected destroys
          ↓
    terraform apply

## Final Takeaway

The main lesson from this issue is that Terraform manages AWS resources through both the actual AWS infrastructure and its state file. A failed Terraform operation does not necessarily mean the AWS resource was never created. Always verify the real AWS resource, inspect Terraform state, understand whether the resource is tainted, and review the Terraform plan before deciding whether to remove, import, recreate, or update the resource.