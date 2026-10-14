# This role creates the trusted AWS identity that github actions can assukme using OIDC token.
# On conditions where trusted repo/branch and is intended for aws sts. 
# why aws sts cuz it is a service that allows you to request temporary, limited-privilege credentials for AWS IAM users or for users that you authenticate (federated users).
resource "aws_iam_role" "github_terraform_role" {
  name = "github-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = concat(
              local.github_oidc_subjects,
              local.github_oidc_environment_subjects
            )
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------
# Terraform Infrastructure Permissions
# ---------------------------------------------------------

resource "aws_iam_role_policy_attachment" "github_terraform_admin" {

  role = aws_iam_role.github_terraform_role.name

  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


# ---------------------------------------------------------
# GitHub ECR IAM Role
# ---------------------------------------------------------

resource "aws_iam_role" "github_ecr_role" {

  name = "github-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc_provider.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = concat(
              local.github_oidc_subjects,
              local.github_oidc_environment_subjects
            )
          }
        }
      }
    ]
  })
}

# This policy allows the role to push images to ECR repositories.
# Mental model - First, GitHub gets the ECR login token → then it is authenticated with the ECR registry → then it can push images only to the specific ECR repositories we allowed.
resource "aws_iam_policy" "github_ecr_policy" {
  name = "github-ecr-push"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",

        ]
        Resource = "*"
      },

      {
        Effect = "Allow"
        Action = [
          # Required to read existing images/cache
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",

          #Required to push new images
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]

        Resource = local.ecr_repository_arn_patterns
      }
    ]
  })
}

# Attach the policy to the iam role to allow to push images
resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
  role       = aws_iam_role.github_ecr_role.name
  policy_arn = aws_iam_policy.github_ecr_policy.arn
}

