# Troubleshooting: GitHub OIDC, Terraform, EKS & Kubernetes Authentication

This README documents the issues encountered while rebuilding the DevOps Dojo infrastructure and how each issue was identified and fixed.

---

## 1. GitHub Actions Terraform Apply Failed — OIDC Subject Mismatch

### Symptom

GitHub Actions had two Terraform jobs:

- `terraform-plan` → passed
- `terraform-apply` → failed at `Configure AWS credentials with OIDC`

The Apply job used:

`environment: ${{ inputs.environment }}`

### Root Cause

GitHub OIDC tokens contain a `sub` (subject) claim.

The Plan job did not use a GitHub Environment, so its subject was:

`repo:Johnson9393/InfraProjects:ref:refs/heads/main`

The Apply job used a GitHub Environment.

For `dev`, GitHub generated:

`repo:Johnson9393/InfraProjects:environment:dev`

For `prod`, GitHub generates:

`repo:Johnson9393/InfraProjects:environment:prod`

The IAM trust policy originally allowed only:

`repo:Johnson9393/InfraProjects:ref:refs/heads/main`

Therefore:

GitHub Apply → OIDC token → IAM trust policy → subject mismatch → AssumeRole failed

### OIDC Mental Model

`sub` = WHO is requesting access.

Examples:

`repo:Johnson9393/InfraProjects:ref:refs/heads/main`

`repo:Johnson9393/InfraProjects:environment:dev`

`aud` = WHO the token is intended for.

For AWS:

`aud = sts.amazonaws.com`

Therefore the IAM trust policy checks:

`sub → Is this GitHub identity/context trusted?`

`aud → Is this token intended for AWS STS?`

Both conditions must match.

### Fix

Added environment subjects:

`github_oidc_environment_subjects = [
  "repo:Johnson9393/InfraProjects:environment:dev",
  "repo:Johnson9393/InfraProjects:environment:prod"
]`

Updated the Terraform role trust policy:

`"token.actions.githubusercontent.com:sub" = concat(
  local.github_oidc_subjects,
  local.github_oidc_environment_subjects
)`

The Terraform role now trusts:

`repo:Johnson9393/InfraProjects:ref:refs/heads/main`

`repo:Johnson9393/InfraProjects:environment:dev`

`repo:Johnson9393/InfraProjects:environment:prod`

### Result

Plan can authenticate using the branch-based subject.

Apply can authenticate using the environment-based subject.

The GitHub Environment was kept on the Apply job so GitHub Environment approval/protection still works.

---

## 2. Local Terraform Plan Failed — Invalid AWS Security Token

### Symptom

Running:

`terraform plan`

locally produced:

`InvalidClientTokenId: The security token included in the request is invalid.`

But:

`aws sts get-caller-identity`

worked.

### Investigation

Checked AWS environment variables:

`env | grep '^AWS_'`

No AWS credential environment variables were present.

Checked AWS configuration:

`aws configure list`

The profile showed:

`<not set>`

Available profiles were checked using:

`aws configure list-profiles`

Result:

`default`

`dojo-dev-admin`

The intended AWS SSO profile was:

`dojo-dev-admin`

### Root Cause

The shell did not have:

`AWS_PROFILE=dojo-dev-admin`

set.

Therefore the AWS CLI/Terraform environment was falling back to the `default` profile.

Terraform was not successfully using the intended SSO profile.

### Fix

Explicitly ran:

`AWS_PROFILE=dojo-dev-admin terraform plan`

Terraform worked successfully.

For future local work:

`export AWS_PROFILE=dojo-dev-admin`

Then:

`aws sts get-caller-identity`

and:

`terraform plan`

will use the intended SSO profile.

### Important Distinction

This issue was completely separate from GitHub OIDC.

Local authentication:

Mac → AWS SSO → Terraform

GitHub authentication:

GitHub Actions → GitHub OIDC → AWS STS → IAM Role → Terraform

---

## 3. GitHub Actions App Infra Failed — kubeconfig Does Not Exist

### Symptom

App Infra Terraform failed with:

`Error: Invalid attribute in provider configuration`

`'config_path' refers to an invalid path: "/home/runner/.kube/config"`

### Root Cause

The Kubernetes provider had originally used:

`config_path = "~/.kube/config"`

This works locally because the Mac already has:

`~/.kube/config`

GitHub Actions runs on a fresh runner.

Therefore:

GitHub Runner → `/home/runner/.kube/config` → file does not exist

### Fix

Changed the Kubernetes provider to authenticate directly against the EKS cluster:

`provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}`

Using:

`data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}`

and:

`data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}`

### Authentication Mental Model

Instead of:

Terraform → `~/.kube/config` → EKS

GitHub Actions uses:

Terraform → EKS endpoint + Cluster CA + EKS auth token → Kubernetes API

Therefore a kubeconfig file is not required on the GitHub runner.

---

## 4. Local kubectl Failed — EKS Authentication

### Symptom

After creating kubeconfig:

`aws eks update-kubeconfig --region us-east-1 --name dojo-eks --profile dojo-dev-admin`

the kubeconfig was successfully updated.

But:

`kubectl get nodes`

returned:

`the server has asked for the client to provide credentials`

### Investigation

AWS authentication itself worked:

`aws sts get-caller-identity --profile dojo-dev-admin`

returned the expected AWS SSO identity.

Therefore the problem was not AWS SSO authentication.

The problem was EKS/Kubernetes access.

---

## 5. EKS Access Entry Missing for Local SSO Role

### Investigation

Checked EKS access entries:

`aws eks list-access-entries \
  --cluster-name dojo-eks \
  --region us-east-1 \
  --profile dojo-dev-admin`

Existing entries included:

`AWSServiceRoleForAmazonEKS`

`example-eks-node-group-...`

`github-terraform-role`

The local SSO Administrator role was not present.

### Root Cause

The SSO role could authenticate to AWS, but EKS did not have an access entry for that IAM role.

Therefore:

AWS authentication → SUCCESS

EKS access entry → MISSING

Kubernetes access → FAILED

### Fix

Created an EKS access entry for:

`arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6`

Command:

`aws eks create-access-entry \
  --cluster-name dojo-eks \
  --principal-arn arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6 \
  --region us-east-1 \
  --profile dojo-dev-admin`

The access entry was successfully created.

---

## 6. kubectl Then Returned Forbidden — Authorization Problem

### Symptom

After creating the EKS access entry:

`kubectl get nodes`

returned:

`Error from server (Forbidden): nodes is forbidden`

### Meaning

This was an important change.

Previously:

`server has asked for credentials`

After creating the access entry:

`Forbidden`

This means authentication was now working, but authorization was not.

Mental model:

AWS SSO identity → EKS Access Entry → Authentication SUCCESS → Authorization FAILED

### Root Cause

The access entry existed but had:

`kubernetesGroups: []`

and no EKS access policy granting sufficient Kubernetes permissions.

---

## 7. Associate AmazonEKSClusterAdminPolicy

### Fix

Associated:

`AmazonEKSClusterAdminPolicy`

with the SSO role.

Command:

`aws eks associate-access-policy \
  --cluster-name dojo-eks \
  --principal-arn arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6 \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1 \
  --profile dojo-dev-admin`

### Result

Running:

`kubectl get nodes`

then returned:

`ip-10-0-3-110.ec2.internal   Ready`

`ip-10-0-4-39.ec2.internal    Ready`

Local kubectl access was successfully restored.

### Final Mental Model

Authentication:

`AWS SSO Role`

`↓`

`EKS Access Entry`

Authorization:

`AmazonEKSClusterAdminPolicy`

`↓`

`Kubernetes API`

`↓`

`kubectl`

Both authentication and authorization are required.

---

## 8. Kubernetes Provider Authentication Mental Model

### Local Machine

Originally:

`Terraform`

`↓`

`~/.kube/config`

`↓`

`EKS Kubernetes API`

This works when kubeconfig exists locally.

### GitHub Actions

Now:

`GitHub Actions`

`↓`

`AWS OIDC`

`↓`

`github-terraform-role`

`↓`

`Temporary AWS credentials`

`↓`

`EKS cluster endpoint`

`+`

`Cluster CA certificate`

`+`

`EKS authentication token`

`↓`

`Kubernetes API`

This avoids depending on `/home/runner/.kube/config`.

---

## 9. App Infra and ALB Controller Dependency

Project structure:

`EKS/eks-core-infra`

Contains:

`VPC`

`EKS Cluster`

`Node Groups`

`EKS/k8s-services`

Contains:

`ALB Controller IAM`

`ALB Controller Helm release`

`dojo-app/infra`

Contains:

`RDS`

`ECR`

`Secrets Manager`

`Kubernetes Namespace`

`ConfigMaps`

`Secrets`

`Services`

`Ingress`

`ACM`

`Route 53`

### Important Understanding

The Kubernetes Ingress object itself does not require the ALB Controller to exist.

However, this project also has:

`data "aws_lb" "ingress"`

which expects to discover the ALB created by the ALB Controller.

Therefore the safer order for the current Terraform design is:

`EKS Core`

`↓`

`EKS/k8s-services`

`↓`

`ALB Controller`

`↓`

`App Infra`

`↓`

`Ingress`

`↓`

`ALB`

`↓`

`aws_lb data source`

`↓`

`Route 53`

The ALB Controller should therefore be installed before running the App Infra that depends on the controller-created ALB.

---

## 10. Ingress Error — Load Balancer Not Ready Yet

### Symptom

App Infra produced:

`Error: Load Balancer is not ready yet`

for:

`kubernetes_ingress_v1.dojo_htpps_ingress`

### Relevant Configuration

The Ingress contains:

`wait_for_load_balancer = true`

This tells Terraform to wait until the Ingress has a Load Balancer assigned.

### Expected Flow

`Terraform creates Ingress`

`↓`

`ALB Controller watches Ingress`

`↓`

`ALB Controller creates/configures ALB`

`↓`

`Ingress receives ALB hostname`

`↓`

`Terraform continues`

### Meaning

The Ingress resource existed, but Terraform did not see the Load Balancer become ready within the waiting period.

Useful troubleshooting command:

`kubectl get ingress -n dojo`

Further troubleshooting can inspect the ALB Controller pods, logs, and Kubernetes events.

---

## 11. Kubernetes Namespace Deprecation Warning

### Warning

Terraform reported:

`Deprecated Resource`

`kubernetes_namespace.dojo`

`Deprecated; use kubernetes_namespace_v1`

### Meaning

The Kubernetes provider considers:

`kubernetes_namespace`

deprecated.

The recommended resource is:

`kubernetes_namespace_v1`

### Future Cleanup

Current:

`resource "kubernetes_namespace" "dojo" {`

Recommended:

`resource "kubernetes_namespace_v1" "dojo" {`

References should also be updated accordingly.

This is a deprecation warning and is separate from the authentication and authorization issues.

---

## 12. Useful Troubleshooting Commands

### Check AWS identity

`aws sts get-caller-identity --profile dojo-dev-admin`

### Check configured profiles

`aws configure list-profiles`

### Check AWS configuration

`aws configure list`

### Set the intended SSO profile

`export AWS_PROFILE=dojo-dev-admin`

### Run Terraform using the intended profile

`AWS_PROFILE=dojo-dev-admin terraform plan`

### Configure local EKS kubeconfig

`aws eks update-kubeconfig \
  --region us-east-1 \
  --name dojo-eks \
  --profile dojo-dev-admin`

### Check EKS nodes

`kubectl get nodes`

### List EKS access entries

`aws eks list-access-entries \
  --cluster-name dojo-eks \
  --region us-east-1 \
  --profile dojo-dev-admin`

### Create EKS access entry

`aws eks create-access-entry \
  --cluster-name dojo-eks \
  --principal-arn <IAM_ROLE_ARN> \
  --region us-east-1 \
  --profile dojo-dev-admin`

### Associate EKS access policy

`aws eks associate-access-policy \
  --cluster-name dojo-eks \
  --principal-arn <IAM_ROLE_ARN> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1 \
  --profile dojo-dev-admin`

### Check Ingress

`kubectl get ingress -n dojo`

### Check all application resources

`kubectl get all -n dojo`

---

## 13. Troubleshooting Decision Flow

When Terraform or kubectl fails, first identify the layer.

### Layer 1 — AWS Authentication

Question:

`Can my AWS identity authenticate?`

Command:

`aws sts get-caller-identity`

If this fails, investigate AWS SSO/profile/credentials.

### Layer 2 — EKS Access Entry

Question:

`Does EKS recognize this IAM identity?`

Command:

`aws eks list-access-entries --cluster-name dojo-eks --region us-east-1 --profile dojo-dev-admin`

### Layer 3 — Kubernetes Authorization

Question:

`Does this identity have Kubernetes permissions?`

Check the EKS access policy associated with the access entry.

### Layer 4 — Kubernetes Resource

Question:

`Does the Kubernetes resource exist and have the expected configuration?`

Examples:

`kubectl get pods -n dojo`

`kubectl get svc -n dojo`

`kubectl get ingress -n dojo`

### Layer 5 — Controller

Question:

`Is the controller watching and processing the resource?`

Examples:

`kubectl get pods -n kube-system`

Check ALB Controller status and logs.

### Layer 6 — AWS Resource

Question:

`Did the controller create the expected AWS resource?`

Examples:

`ALB`

`Target Groups`

`Security Groups`

### Layer 7 — Application

Question:

`Are the application Pods healthy and able to communicate with RDS?`

---

## 14. Key Lessons From This Troubleshooting Session

### OIDC

`sub = WHO`

`aud = FOR WHOM`

### AWS Authentication vs Kubernetes Authentication

Being authenticated to AWS does not automatically mean that you are authorized to access the Kubernetes API.

### Kubernetes Authentication vs Authorization

`Authentication = Who are you?`

`Authorization = What are you allowed to do?`

### GitHub Actions Runner

Never assume that a fresh GitHub runner has your local kubeconfig.

Prefer direct EKS authentication through the Kubernetes provider when Terraform is running in GitHub Actions.

### Terraform Dependency

A Kubernetes resource can exist before its controller.

But if Terraform also depends on an AWS resource created by that controller, the controller needs to exist before Terraform can successfully complete that dependency chain.

### Current Successful Architecture

`GitHub`

`↓`

`GitHub OIDC`

`↓`

`AWS IAM`

`↓`

`EKS Core`

`↓`

`EKS/k8s-services`

`↓`

`ALB Controller`

`↓`

`App Infra`

`↓`

`Kubernetes + RDS + ECR + Secrets + Ingress + ACM + Route 53`

`↓`

`Application Deployments`

`↓`

`Pods`

`↓`

`ALB`

`↓`

`Internet`

This troubleshooting session established the complete authentication, authorization, Terraform, EKS, Kubernetes provider, and ALB Controller relationships required for the DevOps Dojo deployment.