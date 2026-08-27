# GitHub Actions AWS OIDC — Terraform Practical Reference

This configuration is used to allow GitHub Actions to authenticate with AWS using OpenID Connect (OIDC), without storing long-lived AWS Access Keys and Secret Keys in GitHub.

For this project, the trusted GitHub repository is `Johnson9393/InfraProjects` and the trusted branch is `main`.

The basic flow is:

GitHub Actions → OIDC Token → AWS OIDC Provider → IAM Role Trust Policy → AWS STS → Temporary AWS Credentials → IAM Permissions → AWS Services

The complete authentication flow will eventually be:

    GitHub Actions
          ↓
    GitHub OIDC Token
          ↓
    AWS OIDC Provider
          ↓
    IAM Role Trust Policy
          ↓
    Check repository / branch / audience
          ↓
    AssumeRoleWithWebIdentity
          ↓
    AWS STS
          ↓
    Temporary AWS Credentials
          ↓
    IAM Permissions
          ↓
    ECR / Other AWS Services

The GitHub repository information is maintained using a Terraform local:

    locals {
      github_repo = [
        {
          user   = "Johnson9393"
          repo   = "InfraProjects"
          branch = "main"
        }
      ]
    }

`github_repo` is a list of objects. Each object contains the GitHub user, repository, and branch that we want to trust.

The next local converts this repository information into the OIDC subject format:

    github_oidc_subjects = distinct([
      for r in local.github_repo :
      r.branch == "*" ?
      "repo:${r.user}/${r.repo}:*" :
      "repo:${r.user}/${r.repo}:ref:refs/heads/${r.branch}"
    ])

Here, `local.github_repo` contains the complete list of repository objects, while `r` represents the current object during each iteration.

For our current repository:

    r.user   = Johnson9393
    r.repo   = InfraProjects
    r.branch = main

The `for` expression processes every repository in the list and creates an OIDC subject for each repository.

For our configuration, the generated subject is:

    repo:Johnson9393/InfraProjects:ref:refs/heads/main

This is the GitHub OIDC `sub` value that will later be checked by the IAM Role Trust Policy.

The `for` expression is useful because we can add multiple repositories to `github_repo`, and Terraform will automatically generate the corresponding OIDC subject for each repository.

`distinct()` removes duplicate subjects from the resulting list. If the same repository and branch are defined more than once, only one unique subject will remain.

The conditional expression checks whether the branch is a wildcard.

If:

    branch = "main"

the generated subject is:

    repo:Johnson9393/InfraProjects:ref:refs/heads/main

If:

    branch = "*"

the generated subject is:

    repo:Johnson9393/InfraProjects:*

Therefore, `github_oidc_subjects` is essentially converting our simple repository configuration into the exact identity format that AWS will later use to verify the GitHub OIDC token.

The AWS-side OIDC Provider is created using:

    resource "aws_iam_openid_connect_provider" "github_actions" {
      url = "https://token.actions.githubusercontent.com"

      client_id_list = [
        "sts.amazonaws.com"
      ]

      tags = {
        Name = "AWS-GH-aug26"
      }
    }

The URL `https://token.actions.githubusercontent.com` is GitHub's OIDC issuer. By configuring this URL in AWS IAM, we are telling AWS that GitHub is a trusted OIDC identity provider.

The OIDC Provider does not give GitHub any AWS permissions. It only establishes that AWS recognizes GitHub as a trusted identity issuer.

The `client_id_list` contains:

    sts.amazonaws.com

This represents the expected audience (`aud`) of the GitHub OIDC token. In this setup, the token is intended to be used with AWS STS.

The authentication flow is therefore:

    GitHub Actions
          ↓
    GitHub generates OIDC Token
          ↓
    AWS OIDC Provider
          ↓
    AWS recognizes GitHub as a trusted issuer

The tags are only used to identify the OIDC Provider inside AWS and have no role in authentication or authorization.

At this stage, we have created the AWS-side OIDC Provider and generated the trusted GitHub OIDC subject:

    repo:Johnson9393/InfraProjects:ref:refs/heads/main

However, GitHub Actions is not yet authorized to access AWS resources.

The next part is the IAM Role and its Trust Policy. The OIDC Provider establishes that AWS trusts GitHub, while the IAM Role Trust Policy will determine whether the specific GitHub repository and branch are allowed to assume the role.

## IAM Role

The IAM Role is the AWS identity that GitHub Actions will assume using its OIDC token. Its Trust Policy defines who is allowed to assume the role.

```hcl
resource "aws_iam_role" "aws_github_oidc_aug26" {
  name = "aws-github-oidc-aug26"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.github_oidc_subjects
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

The `aws_iam_role` resource creates an IAM Role that GitHub Actions can assume. The `assume_role_policy` is the Trust Policy, which defines who is allowed to assume the role. `Principal` trusts the GitHub OIDC Provider we created earlier, `sts:AssumeRoleWithWebIdentity` allows the role to be assumed using the GitHub OIDC token, and the `Condition` checks that the token comes from our trusted GitHub repository/branch (`sub`) and is intended for AWS STS (`aud`). If these checks pass, AWS allows GitHub Actions to assume the role and receive temporary credentials.

## ECR Permission Policy and Role Attachment

After creating the GitHub OIDC Provider and IAM Role with its Trust Policy, we need to define **what GitHub Actions is allowed to do after it assumes the role**. For our project, GitHub Actions only needs permission to authenticate with ECR and push the backend and frontend Docker images.

The ECR policy is created using:

resource "aws_iam_policy" "github_ecr_policy" {
  name = "github-ecr-push"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]

        Resource = [
          data.aws_ecr_repository.backend.arn,
          data.aws_ecr_repository.frontend.arn
        ]
      }
    ]
  })
}

The first permission, `ecr:GetAuthorizationToken`, allows GitHub Actions to get the ECR login token. `Resource = "*"` is required here because this ECR action works at the registry level and cannot be restricted to one particular repository.

The second permission contains the actions required to push a Docker image. These permissions are restricted to only our backend and frontend ECR repositories using their repository ARNs.

The basic flow is:

GitHub Actions → Get ECR Login Token → Authenticate with ECR → Push Image → Backend/Frontend ECR

Because the ECR repositories are created in a different Terraform project/state, we use ECR data sources to get their existing ARNs instead of directly referencing the ECR resources:

data "aws_ecr_repository" "backend" {
  name = "${var.project}-${var.env}-backend"
}

data "aws_ecr_repository" "frontend" {
  name = "${var.project}-${var.env}-frontend"
}

The data sources look up the already-existing ECR repositories in AWS and return their ARNs, which are then used in the IAM policy.

Finally, the ECR policy is attached to the GitHub Actions IAM Role:

resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
  role       = aws_iam_role.aws_oidc_role.name
  policy_arn = aws_iam_policy.github_ecr_policy.arn
}

This attachment connects the ECR permissions to the IAM Role. Therefore, after GitHub Actions successfully passes the OIDC Trust Policy and assumes the role, it receives the ECR permissions defined in this policy.

Simple mental model:

OIDC + Trust Policy → Who can assume the role?

ECR Policy → What can the role do?

Policy Attachment → Connects the ECR permissions to the role.

For this project, the final result is:

GitHub Actions → OIDC Authentication → IAM Role → ECR Policy → ECR Login → Push Backend/Frontend Images

**Simple meaning:** This code tells AWS, “Trust GitHub, but only allow our specified GitHub repository/branch to assume this role through OIDC.”

The important distinction is that OIDC establishes the GitHub identity, the OIDC Provider establishes AWS's trust in GitHub, the IAM Trust Policy decides which GitHub identity can assume the role, AWS STS provides temporary credentials, and IAM Permissions decide what GitHub Actions can actually do.

For the DevOps Dojo project, the final use case will be GitHub Actions authenticating to AWS through OIDC, assuming the IAM role, receiving temporary AWS credentials, authenticating with ECR, and pushing the backend and frontend Docker images without using long-lived AWS credentials.