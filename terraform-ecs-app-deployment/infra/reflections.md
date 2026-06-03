## Why is `provider.tf` used when Terraform can create resources without it?

### Question

I was able to create AWS resources without defining a `provider.tf` file. What is the purpose of `provider.tf` and when should it be used?

### Answer

Terraform can create AWS resources without an explicit `provider "aws"` block if AWS credentials and region are already configured through the AWS CLI or environment variables. In this case, Terraform automatically uses the default AWS provider configuration.

However, a `provider.tf` file is commonly used to explicitly configure the AWS provider. This provides several benefits:

* Defines the AWS region in code, ensuring consistency across environments.
* Configures default tags that are automatically applied to all supported resources.
* Supports role assumption for cross-account access.
* Enables multiple provider configurations using aliases for different AWS accounts or regions.

Example:

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

Although Terraform can work without a `provider.tf` file, using one improves maintainability, consistency, and makes the infrastructure configuration self-contained.

----

## Why does the Terraform state file remain in S3 after `terraform destroy`?

### Question

I configured an S3 backend for Terraform state storage. When I ran `terraform destroy`, all AWS resources such as the VPC were deleted, but the state file remained in the S3 bucket. Why was the state file not deleted?

### Answer

This is expected behavior. Terraform only destroys the infrastructure resources that it manages and tracks in the state file. The remote backend (S3 bucket and the state file stored within it) is not considered a managed resource unless it is explicitly defined as one in the Terraform configuration.

When `terraform destroy` is executed:

* Managed infrastructure resources (VPCs, subnets, route tables, security groups, etc.) are deleted.
* The Terraform state file remains in the S3 bucket.
* The S3 bucket used as the backend is not deleted.

The state file is retained because Terraform uses it as a record of the infrastructure it managed, even after the resources have been destroyed.

If the state file is no longer required, it must be removed manually, for example:

```bash id="a8m31v"
aws s3 rm s3://sp-state-bucket/infra/terraform.tfstate
```

### Key Learning

Terraform destroys infrastructure resources but does not automatically delete the remote backend or the state file stored in it. Backend resources must be managed and removed separately if required.

---

# Task 6 — Concept Questions

## 1. What is idempotency in Terraform and why does it matter for infrastructure?

**Answer:**
Idempotency means that running the same Terraform configuration multiple times produces the same result without creating duplicate resources. It is important because infrastructure can be applied repeatedly in a predictable and consistent manner, reducing configuration drift and human errors.

---

## 2. What is a Terraform state file? What happens if two people apply from the same repo simultaneously without state locking?

**Answer:**
A Terraform state file stores information about the infrastructure resources managed by Terraform and maps them to the configuration. If two people run `terraform apply` simultaneously without state locking, they may overwrite each other's changes, resulting in state corruption, resource conflicts, or inconsistent infrastructure.

---

## 3. What is the difference between a resource block and a data block? When would you use each?

**Answer:**
A resource block creates, updates, or deletes infrastructure managed by Terraform. A data block reads information about existing infrastructure without managing it. Resource blocks are used when provisioning new resources, while data blocks are used to reference existing resources such as VPCs, AMIs, or security groups.

---

## 4. What is implicit dependency? Give one example from your VPC code.

**Answer:**
An implicit dependency occurs when one resource references an attribute of another resource, causing Terraform to determine the correct creation order automatically. For example, a subnet that uses `aws_vpc.main.id` has an implicit dependency on the VPC, so Terraform creates the VPC before the subnet.

---

## 5. When would you choose a VPC endpoint over a NAT gateway? Consider both cost and security.

**Answer:**
A VPC endpoint is preferred when resources need to access AWS services such as S3 or DynamoDB without traversing the public internet. It is generally more secure because traffic remains within the AWS network and can be more cost-effective than routing all traffic through a NAT Gateway.

---

## 6. Why do we keep RDS subnets separate from private app subnets — what problem does it solve?

**Answer:**
Keeping RDS subnets separate from private application subnets provides better network isolation and security. It allows database resources to have dedicated routing and access controls, reducing the risk of accidental exposure and making infrastructure management easier as the environment grows.

---


