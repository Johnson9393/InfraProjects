# ShopSphere Secrets Management Design

## 1. Design We Are Following

ShopSphere uses **AWS Secrets Manager as the central source of truth for application secrets**.

The design separates:

- **Secret definitions and values** → `locals.tf`
- **Secret creation and storage in AWS Secrets Manager** → `secrets.tf`
- **External/sensitive inputs** → `variables.tf`
- **Environment selection** → `var.env`
- **AWS account selection** → AWS provider configuration

The flow we have built so far is:

Terraform → `locals.tf` → `secrets.tf` → AWS Secrets Manager

The next layer will be:

AWS Secrets Manager → External Secrets Operator (ESO) → Kubernetes Secret → Application Pod

ESO is intentionally **not implemented yet**.

## 2. Why We Designed It This Way

We want **one reusable Terraform codebase** instead of separate Terraform code for Dev, UAT, Prod, etc.

The environment is selected dynamically using:

```text
var.env
```

For example:

```text
var.env = "dev"
var.env = "prod"
```

The AWS account is selected separately through the AWS provider, credentials, profile, or assumed role.

Therefore the same Terraform code can be used for:

- Dev environment in the Dev AWS account
- Prod environment in the Prod AWS account
- Multiple environments in the same AWS account, if required

We do not hardcode separate secret resource definitions for each environment.

## 3. Role of locals.tf

`locals.tf` contains the **logical definition of the ShopSphere secrets**.

It defines:

- Which Kubernetes secrets are required
- Which keys each secret contains
- What values should be stored
- How environment-aware secret targets are constructed

For example, Product Service requires:

```text
product-db-credentials
```

with:

```text
username
password
```

The logical value is defined in `local.secret_values`:

```hcl
"product-db-credentials" = {
  username = "product_user"
  password = random_password.db[var.env].result
}
```

The important point is:

**`locals.tf` does not create the AWS Secret itself.**

It only defines the secret data and mappings that Terraform will use.

## 4. Role of secrets.tf

`secrets.tf` contains the reusable Terraform resources that create the actual AWS Secrets Manager objects.

The first resource creates the Secret container dynamically:

```hcl
resource "aws_secretsmanager_secret" "shopsphere" {
  for_each = local.secret_mappings

  name = "shopsphere/${var.env}/${each.key}"
}
```

The second resource stores the JSON value:

```hcl
resource "aws_secretsmanager_secret_version" "shopsphere" {
  for_each = local.secret_values

  secret_id     = aws_secretsmanager_secret.shopsphere[each.key].id
  secret_string = jsonencode(each.value)
}
```

We therefore write the Terraform resource only once.

`for_each` creates the required AWS Secrets Manager objects dynamically based on the definitions in `locals.tf`.

## 5. Product DB Credentials Example

Suppose we deploy the Dev environment:

```text
var.env = "dev"
```

Our `locals.tf` definition contains:

```text
product-db-credentials
    username = product_user
    password = generated password
```

`secrets.tf` automatically creates:

```text
shopsphere/dev/product-db-credentials
```

The stored JSON is conceptually:

```json
{
  "username": "product_user",
  "password": "<generated-password>"
}
```

Now the exact same Terraform code is used for Prod:

```text
var.env = "prod"
```

It automatically creates:

```text
shopsphere/prod/product-db-credentials
```

with the corresponding Prod secret value.

We do not need separate Terraform files such as:

```text
dev-product-db-secret.tf
prod-product-db-secret.tf
```

The environment is handled dynamically.

## 6. How Multi-Environment Works

The environment is included in the AWS Secrets Manager secret name:

```text
shopsphere/<environment>/<secret-name>
```

For example:

```text
shopsphere/dev/product-db-credentials
shopsphere/prod/product-db-credentials
```

The same Terraform code can therefore create different environment secrets simply by changing:

```text
var.env
```

The Kubernetes namespaces are also environment-specific:

```text
shopsphere-dev
shopsphere-prod
```

Later, ESO will use the appropriate environment's AWS secret and create the corresponding Kubernetes Secret inside the correct namespace.

## 7. How Multi-Account Works

Environment selection and AWS account selection are intentionally separate.

For example:

```text
Dev AWS Account
    +
var.env = dev
    ↓
shopsphere/dev/product-db-credentials
```

and:

```text
Prod AWS Account
    +
var.env = prod
    ↓
shopsphere/prod/product-db-credentials
```

The Terraform code remains the same.

The AWS provider determines **which AWS account Terraform is operating against**.

`var.env` determines **which environment's resource naming and configuration is being created**.

This gives us a reusable Terraform codebase across multiple environments and AWS accounts without duplicating the secret resource definitions.

## 8. What locals.tf and secrets.tf Do Together

The relationship is simple:

```text
locals.tf
    ↓
Defines:
- secret names
- secret keys
- secret values
- mappings
    ↓
secrets.tf
    ↓
Creates:
- AWS Secrets Manager Secret
- Secret Version
- JSON secret data
    ↓
AWS Secrets Manager
```

For example:

```text
local.secret_values["product-db-credentials"]
        ↓
aws_secretsmanager_secret_version.shopsphere["product-db-credentials"]
        ↓
aws_secretsmanager_secret.shopsphere["product-db-credentials"]
        ↓
shopsphere/dev/product-db-credentials
```

The Secret Version does not need to separately know the environment.

It references the exact Secret resource instance created by `secrets.tf`, and that Secret resource already contains:

```text
shopsphere/${var.env}/...
```

Therefore the environment is naturally carried through the resource relationship.

## 9. External Credentials

Not every secret is generated by Terraform.

For example, Razorpay credentials are external values.

They are supplied through sensitive Terraform variables:

```text
razorpay_key_id
razorpay_key_secret
razorpay_webhook_secret
```

Those values are then included in the appropriate `local.secret_values` entry.

This allows Terraform to place the external credentials into AWS Secrets Manager while keeping the reusable Terraform structure environment-independent.

The same approach is currently being used for the temporary AWS credentials required by the Notification Service.

Later, the Notification Service will move to an AWS workload identity approach such as **EKS Pod Identity**, removing the need for static AWS access keys.

## 10. Current Secrets Architecture

The architecture we have completed so far is:

```text
Terraform Variables
        ↓
    locals.tf
        ↓
    secrets.tf
        ↓
AWS Secrets Manager
```

The complete target architecture will eventually become:

```text
Terraform
    ↓
AWS Secrets Manager
    ↓
External Secrets Operator
    ↓
Kubernetes Secret
    ↓
ShopSphere Pod
```

## 11. What We Achieved

The Secrets Manager foundation for ShopSphere is now designed to be:

- Reusable
- Environment-aware
- Multi-account capable
- Dynamically generated using `for_each`
- Centrally managed
- Compatible with the Helm secret contract
- Ready for External Secrets Operator

Specifically, we have implemented:

- `locals.tf` for secret definitions, mappings, and values
- `secrets.tf` for AWS Secrets Manager resources
- Environment-aware secret naming
- Dynamic secret creation
- Dynamic JSON secret values
- Generated credentials for internal application components
- External credentials through sensitive Terraform variables
- `var.env` for environment selection
- AWS provider configuration for account selection

## 12. Practical Mental Model

Remember the design this way:

```text
variables.tf
    ↓
External inputs

locals.tf
    ↓
What secrets we need
+
What values they contain
+
How they map to Kubernetes

secrets.tf
    ↓
Create AWS Secrets Manager objects
+
Store JSON values

AWS Secrets Manager
    ↓
Next phase: ESO
    ↓
Kubernetes Secrets
    ↓
Application Pods
```

The key principle is:

**`locals.tf` describes the secret data; `secrets.tf` implements the AWS resources that store that data.**

Because both are driven by `var.env`, the same Terraform code works across environments and AWS accounts without duplicating the secret resource definitions.

## 13. Next Phase

The next implementation phase is:

```text
eso.tf
```

Its responsibility will be to connect:

```text
AWS Secrets Manager
        ↓
External Secrets Operator
        ↓
Kubernetes Secrets
```

That will be implemented separately without changing the fundamental `locals.tf` + `secrets.tf` design established here.