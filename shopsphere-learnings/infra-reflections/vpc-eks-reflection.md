# EKS Infrastructure Reflections

## 1. EBS CSI IAM Role — Circular Dependency

### Issue
Terraform detected a dependency cycle:

```text
module.eks
   ↓
aws_iam_role.ebs_csi_driver
   ↓
aws_iam_openid_connect_provider.eks_oidc_provider
   ↓
module.eks
```

The EBS CSI add-on was inside the EKS module while its IAM role depended on the EKS OIDC provider, which itself depended on the EKS cluster.

### Fix

Removed the EBS CSI add-on from:

```text
modules/eks/addons.tf
```

and moved it to:

```text
infra/core-infra/addons.tf
```

The EKS module exposed the OIDC issuer through `outputs.tf`:

```hcl
output "cluster_oidc_issuer_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
```

The CSI add-on was then created from the root infrastructure layer:

```hcl
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
}
```

### Verification

```bash
terraform validate
terraform plan -var-file=vars/dev.tfvars
```

Expected result:

```text
Plan: 41 to add, 0 to change, 0 to destroy
```

---

## 2. EKS Access Entry — Missing Access Configuration

### Issue
The EKS Access Entry configuration failed because the cluster was not configured to use the required EKS API/ConfigMap authentication mode.

### Fix

Added this to the EKS cluster configuration:

```hcl
access_config {
  authentication_mode = "API_AND_CONFIG_MAP"
}
```

This enabled both EKS API-based access entries and the existing ConfigMap-based mechanism.

### Verification

```bash
terraform validate
terraform plan -var-file=vars/dev.tfvars
```

The Access Entry could then be created successfully.

---

## 3. EKS Access Entry Already Exists — Terraform State Mismatch

### Issue
During `terraform apply`, AWS reported that the EKS Access Entry already existed.

The resource was present in AWS, but it was not yet present in Terraform state.

Cluster:

```text
dev-shopsphere
```

Principal:

```text
arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6
```

### Verify Existing Access Entry

```bash
aws eks describe-access-entry \
  --cluster-name dev-shopsphere \
  --principal-arn arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6
```

### Fix — Import Existing AWS Resource

```bash
terraform import -var-file=vars/dev.tfvars \
'module.eks.aws_eks_access_entry.cluster_admins["arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6"]' \
'dev-shopsphere:arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6'
```

Then verify the state/plan:

```bash
terraform plan -var-file=vars/dev.tfvars
```

Finally:

```bash
terraform apply -var-file=vars/dev.tfvars
```

After importing the existing Access Entry into Terraform state, the infrastructure applied successfully.