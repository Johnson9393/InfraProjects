# EKS OIDC, ServiceAccount & IAM Role — ALB Controller

## 1. Why does the ALB Controller need an IAM Role?

The AWS Load Balancer Controller runs as a Kubernetes Pod inside EKS.

It needs to call AWS APIs to create and manage resources such as:

- Application Load Balancers
- Target Groups
- Listeners
- Security Groups
- ALB routing rules

Therefore, the Pod needs an AWS identity with appropriate permissions.

The flow is:

Kubernetes Pod
→ ServiceAccount
→ EKS OIDC
→ IAM Role
→ Temporary AWS credentials
→ AWS APIs

---

## 2. What is a Kubernetes ServiceAccount?

A ServiceAccount is the identity assigned to a Kubernetes Pod.

Our ALB Controller will use:

    Namespace: kube-system
    ServiceAccount: aws-load-balancer-controller

Its Kubernetes identity is represented as:

    system:serviceaccount:kube-system:aws-load-balancer-controller

Think:

- Human → IAM User/Role identity
- Pod → Kubernetes ServiceAccount identity

---

## 3. Why do we need EKS OIDC?

Kubernetes has its own identity system, but AWS IAM needs a way to recognize that Kubernetes identity.

EKS provides an OIDC issuer for the cluster.

Example:

    https://oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ

OIDC acts as the bridge between:

    Kubernetes identity
            ↓
       EKS OIDC
            ↓
        AWS IAM

This allows AWS IAM to trust a Kubernetes ServiceAccount.

---

## 4. Getting the EKS OIDC Provider

We use:

    data "aws_iam_openid_connect_provider" "eks" {
      url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
    }

The EKS cluster contains the OIDC issuer information.

Terraform extracts it using:

    data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

The `[0]` is required because Terraform exposes these nested values as lists.

The path is:

    cluster
      ↓
    identity
      ↓
    [0]          → first item
      ↓
    oidc
      ↓
    [0]          → first item
      ↓
    issuer

The result is something like:

    https://oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ

---

## 5. IAM Role

We create:

    resource "aws_iam_role" "aws_load_balancer_controller"

The IAM Role represents the AWS identity that the ALB Controller will use.

The role has two important parts:

    IAM Role
    ├── Trust Policy
    │     → WHO can assume this role?
    │
    └── IAM Policy
          → WHAT can this role do?

The IAM Role itself does not automatically give permissions.

The IAM Policy gives the permissions.

---

## 6. Assume Role Policy / Trust Policy

Inside the IAM Role we have:

    assume_role_policy = jsonencode({
      ...
    })

This is the Trust Policy.

It answers:

    "Who is allowed to assume this IAM Role?"

For our ALB Controller:

    ALB Controller ServiceAccount
              ↓
         OIDC token
              ↓
       IAM Role Trust Policy
              ↓
          IAM Role

The trust policy does NOT define ALB permissions.

It only defines who is trusted to assume the role.

---

## 7. Federated Principal

We have:

    Principal = {
      Federated = data.aws_iam_openid_connect_provider.eks.arn
    }

`Federated` means we are trusting an external identity provider.

In our case, that external identity provider is the EKS OIDC provider.

So:

    EKS OIDC Provider
          ↓
    identifies the Kubernetes identity
          ↓
    IAM Role trusts that identity

The role is therefore not trusting every Kubernetes Pod.

It trusts identities coming through this specific EKS OIDC provider.

---

## 8. AssumeRoleWithWebIdentity

We have:

    Action = "sts:AssumeRoleWithWebIdentity"

This tells AWS:

    "Allow this OIDC/web identity to assume this IAM Role through AWS STS."

STS means:

    AWS Security Token Service

The practical flow is:

    ALB Controller Pod
          ↓
    ServiceAccount
          ↓
    OIDC token
          ↓
    AWS STS
          ↓
    Assume IAM Role
          ↓
    Temporary AWS credentials
          ↓
    Call AWS APIs

STS is responsible for the role-assumption process and temporary credentials.

---

## 9. What is the Condition?

We don't want every Kubernetes identity to use this IAM Role.

We only want:

    system:serviceaccount:kube-system:aws-load-balancer-controller

Therefore, we add:

    Condition = {
      StringEquals = {
        ...
      }
    }

The condition adds an extra security check.

---

## 10. Why StringEquals?

`StringEquals` means:

    Actual value == Expected value

The values must match exactly.

Example:

    Actual:
    system:serviceaccount:kube-system:aws-load-balancer-controller

    Expected:
    system:serviceaccount:kube-system:aws-load-balancer-controller

    → MATCH → Allowed

But if another ServiceAccount tries:

    system:serviceaccount:dojo:frontend

Then:

    frontend
        ≠
    aws-load-balancer-controller

    → DENIED

---

## 11. The `sub` / Subject Condition

We have:

    "...:sub" =
    "system:serviceaccount:kube-system:aws-load-balancer-controller"

`sub` means Subject.

Practically:

    sub → WHO is requesting?

The OIDC token contains the identity of the Kubernetes ServiceAccount.

Example:

    sub =
    system:serviceaccount:kube-system:aws-load-balancer-controller

The IAM Role says:

    Only this exact ServiceAccount can assume me.

This prevents another ServiceAccount from using the ALB Controller's IAM Role.

---

## 12. The `aud` / Audience Condition

We have:

    "...:aud" = "sts.amazonaws.com"

`aud` means Audience.

Practically:

    aud → WHO is this token intended for?

Our token is intended for:

    sts.amazonaws.com

Why?

Because the token is being presented to AWS STS to assume the IAM Role.

So:

    sub → WHO are you?
          ALB Controller ServiceAccount

    aud → WHO is this token intended for?
          AWS STS

Both must match the trust policy.

---

## 13. Why do we remove `https://`?

The EKS OIDC issuer looks like:

    https://oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ

But the IAM condition key is written using:

    oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ:sub

Therefore we use:

    replace(
      data.aws_iam_openid_connect_provider.eks.url,
      "https://",
      ""
    )

This removes only:

    https://

Example:

    https://oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ

            ↓ replace()

    oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ

Then Terraform adds:

    :sub

Result:

    oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ:sub

Similarly, for the audience:

    oidc.eks.us-east-1.amazonaws.com/id/ABC123XYZ:aud

---

## 14. Complete Trust Flow

    ALB Controller Pod
            ↓
    Kubernetes ServiceAccount
    aws-load-balancer-controller
            ↓
    OIDC Token
            ↓
    EKS OIDC Provider
            ↓
    AWS STS
            ↓
    IAM Role Trust Policy
            ↓
       Check `sub`
       Is this the ALB Controller ServiceAccount?
            ↓
       Check `aud`
       Is the token intended for AWS STS?
            ↓
          MATCH
            ↓
    Assume IAM Role
            ↓
    Temporary AWS credentials
            ↓
    IAM Policy permissions
            ↓
    Create / Manage AWS ALB

---

## 15. Easy Recall

    ServiceAccount
    → Identity of the Kubernetes Pod

    EKS OIDC
    → Bridge that lets AWS recognize the Kubernetes identity

    IAM Role
    → AWS identity the Pod can assume

    Trust Policy
    → WHO can assume the role?

    Federated
    → Trust an external identity provider (EKS OIDC)

    STS
    → Handles role assumption and temporary AWS credentials

    sub
    → WHO is requesting?

    aud
    → WHO is the token intended for?

    StringEquals
    → Actual value must exactly match expected value

    replace("https://", "")
    → Removes the URL scheme so the OIDC issuer matches the IAM condition-key format

    IAM Policy
    → WHAT can the ALB Controller do after assuming the role?