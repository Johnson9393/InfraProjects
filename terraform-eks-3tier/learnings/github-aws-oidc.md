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



The important distinction is that OIDC establishes the GitHub identity, the OIDC Provider establishes AWS's trust in GitHub, the IAM Trust Policy decides which GitHub identity can assume the role, AWS STS provides temporary credentials, and IAM Permissions decide what GitHub Actions can actually do.

For the DevOps Dojo project, the final use case will be GitHub Actions authenticating to AWS through OIDC, assuming the IAM role, receiving temporary AWS credentials, authenticating with ECR, and pushing the backend and frontend Docker images without using long-lived AWS credentials.