# IAM (Identity and Access Management) — Notes

## Overview

IAM is a core AWS service used to securely control access to AWS resources. It defines **who can access what** and **what actions they can perform**.

---

## Key Components

### IAM Users

* Represents a person or application
* Has long-term credentials (password or access keys)
* Typically used for human access (not recommended for EC2)

---

### IAM Roles

* Used by AWS services (EC2, Lambda, etc.)
* No permanent credentials
* Provides **temporary credentials automatically**
* Preferred way to grant permissions to resources

---

### IAM Policies

* JSON documents that define permissions
* Specify:

  * Actions (e.g., `s3:GetObject`)
  * Resources (e.g., specific bucket)
  * Effect (Allow/Deny)

---

## Types of Policies

### AWS Managed Policy

* Predefined by AWS
* Broad permissions
* Example: `AmazonS3ReadOnlyAccess`

### Customer Managed Policy

* Custom policy created by you
* Reusable across multiple roles/users
* Follows least privilege principle

### Inline Policy

* Attached directly to a single user/role
* Not reusable
* Used for one-off or tightly scoped permissions

---

## Trust Policy vs Permission Policy

* **Trust Policy**

  * Defines *who can assume the role*
  * Example: EC2 service allowed to assume role

* **Permission Policy**

  * Defines *what actions are allowed*
  * Example: Access S3 bucket

---

## Common Use Cases

1. **EC2 accessing S3**

   * Attach IAM role to EC2
   * No need for access keys
   * Secure and recommended

2. **Lambda accessing DynamoDB**

   * Role provides required permissions

3. **Cross-account access**

   * Role in Account A trusted by Account B

4. **Restricting access**

   * Custom policy allows access only to specific resources

---

## Best Practices

* Use **roles instead of access keys**
* Follow **least privilege principle**
* Avoid using root account
* Rotate credentials regularly (if used)
* Use customer-managed policies over broad AWS-managed ones

---

## Interview One-Liner

IAM controls authentication and authorization in AWS using users, roles, and policies, where roles provide temporary credentials and policies define access permissions.
