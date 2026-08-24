# GitHub Actions AWS OIDC — Complete Concept Reference

## 1. What is OIDC?

**OIDC (OpenID Connect)** is an identity/authentication mechanism that allows one system to prove its identity to another system using a signed identity token.

In our case:

```text
GitHub Actions
      ↓
OIDC Token
      ↓
AWS
```

GitHub does not need to store a long-lived AWS Access Key and Secret Key.

### Simple meaning

> **OIDC answers: "Who are you?"**

---

## 2. Why do we use OIDC?

### Old approach

```text
GitHub Actions
      ↓
AWS Access Key + Secret Key
      ↓
AWS
```

These are long-lived credentials and must be stored and rotated.

### OIDC approach

```text
GitHub Actions
      ↓
OIDC Token
      ↓
AWS
      ↓
Temporary AWS Credentials
```

The credentials are temporary and expire automatically.

### Main advantage

> **No long-lived AWS credentials need to be stored in GitHub Secrets.**

---

# 3. OIDC Identity Provider

AWS needs to know which identity issuer it trusts.

Therefore, we configure an **OIDC Identity Provider** in AWS IAM for GitHub.

```text
AWS IAM
   ↓
OIDC Identity Provider
   ↓
GitHub
```

GitHub's OIDC issuer is:

```text
https://token.actions.githubusercontent.com
```

The provider basically tells AWS:

> **"I trust identity tokens issued by GitHub."**

The OIDC Provider itself does **not** give GitHub AWS permissions.

---

# 4. OIDC Token

When a GitHub Actions workflow runs, GitHub can generate an OIDC token.

The token contains identity information called **claims**.

Conceptually:

```text
OIDC Token
│
├── Issuer       → GitHub
├── Repository   → my-org/devops-dojo
├── Branch       → main
└── Other claims
```

AWS uses these claims to determine exactly who is requesting access.

---

# 5. IAM Role

We create an IAM Role specifically for GitHub Actions.

Example:

```text
GitHubActionsRole
```

GitHub does not directly receive permanent credentials for this role.

Instead:

```text
GitHub
   ↓
OIDC Token
   ↓
Assume IAM Role
   ↓
Temporary Credentials
```

---

# 6. Trust Policy

The IAM Role has a **Trust Policy**.

The Trust Policy answers:

> **"WHO is allowed to assume this role?"**

For example:

```text
GitHub OIDC
     ↓
Repository = my-org/devops-dojo
     ↓
Branch = main
     ↓
ALLOW
```

A different repository or unauthorized branch can be denied.

### Remember

```text
Trust Policy
     ↓
WHO can assume the role?
```

---

# 7. Permissions Policy

After the role is assumed, the role needs permissions.

The Permissions Policy answers:

> **"WHAT can this role do?"**

For our project:

```text
GitHubActionsRole
       ↓
ECR Permissions
       ↓
Push Backend Image
Push Frontend Image
```

### Remember

```text
Trust Policy       → WHO?
Permissions Policy → WHAT?
```

These are two completely different responsibilities.

---

# 8. AWS STS

**STS (Security Token Service)** is the AWS service that provides temporary credentials after the role assumption is approved.

The flow is:

```text
GitHub
   ↓
OIDC Token
   ↓
IAM Trust Policy
   ↓
AWS STS
   ↓
Temporary Credentials
```

The temporary credentials contain:

```text
Access Key
Secret Key
Session Token
```

They have a limited lifetime and automatically expire.

---

# 9. AssumeRoleWithWebIdentity

This is the AWS STS operation that connects the OIDC token with the IAM Role.

GitHub effectively tells AWS:

> "Here is my OIDC identity token. I want to assume this IAM role."

AWS performs:

```text
AssumeRoleWithWebIdentity
```

Conceptually:

```text
OIDC Token
     +
IAM Role
     ↓
AssumeRoleWithWebIdentity
     ↓
Temporary AWS Credentials
```

---

# 10. Complete Authentication Flow

The complete process is:

```text
GitHub Actions
      ↓
GitHub generates OIDC Token
      ↓
AWS OIDC Identity Provider
      ↓
AWS validates the token
      ↓
IAM Role Trust Policy
      ↓
Checks repository/branch/claims
      ↓
AssumeRoleWithWebIdentity
      ↓
AWS STS
      ↓
Temporary AWS Credentials
      ↓
IAM Permissions Policy
      ↓
AWS Resources
```

For our project:

```text
GitHub Actions
      ↓
OIDC
      ↓
GitHubActionsRole
      ↓
ECR Permissions
      ↓
Backend ECR
Frontend ECR
```

---

# 11. Authentication vs Authorization

This is the most important distinction.

### Authentication

> **Who are you?**

```text
OIDC
   ↓
GitHub proves its identity
```

### Authorization

> **What are you allowed to do?**

```text
IAM Role
   ↓
IAM Permissions
   ↓
ECR Push
```

Therefore:

```text
OIDC
 ↓
Authentication / Identity
 ↓
IAM Trust Policy
 ↓
Role Assumption
 ↓
IAM Permissions
 ↓
Authorization
```

---

# 12. Why OIDC is More Secure

### Long-lived credentials

```text
GitHub Secret
     ↓
AWS Access Key
     ↓
Long-lived
```

If exposed, the credential can remain usable until it is revoked or rotated.

### OIDC

```text
GitHub
   ↓
OIDC Token
   ↓
STS
   ↓
Temporary Credentials
   ↓
Expire automatically
```

The GitHub workflow does not need a permanent AWS secret.

---

# 13. Our DevOps Dojo Use Case

Our pipeline is:

```text
Developer
    ↓
Git Push
    ↓
GitHub Actions
    ↓
OIDC Authentication
    ↓
Assume GitHubActionsRole
    ↓
Temporary AWS Credentials
    ↓
ECR Authentication
    ↓
Build Backend Image
    ↓
Build Frontend Image
    ↓
Push Images to ECR
    ↓
EKS Deployment
```

The Terraform side will create:

```text
AWS OIDC Provider
        ↓
GitHub Actions IAM Role
        ↓
Trust Policy
        ↓
ECR Permissions
```

---

# 14. Final Mental Model

Remember these four questions:

```text
1. Who are you?
       ↓
     OIDC

2. Do I trust your identity?
       ↓
   OIDC Provider + Trust Policy

3. How do you get AWS access?
       ↓
   STS AssumeRoleWithWebIdentity

4. What can you do?
       ↓
   IAM Permissions
```

### One-line summary

> **GitHub proves its identity to AWS using OIDC → AWS validates the identity through the OIDC Provider and IAM Trust Policy → STS provides temporary credentials by assuming the IAM Role → IAM Permissions determine what GitHub can do, such as pushing images to ECR.**
