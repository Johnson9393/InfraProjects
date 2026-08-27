locals {
  github_repo = [
    { user = "Johnson9393", repo = "InfraProjects", branch = "main" }
  ]


#Converted github_repo list into github_oidc_subjects list to be used in aws_iam_openid_connect_provider resource.
# format that aws oidc expects is repo:<user>/<repo>:ref:refs/heads/<branch> or repo:<user>/<repo>:* for all branches. Hence we are using a for loop to convert the list into the required format.
  github_oidc_subjects = distinct([
    for r in local.github_repo :
    r.branch == "*" ?
    "repo:${r.user}/${r.repo}:*" :
    "repo:${r.user}/${r.repo}:ref:refs/heads/${r.branch}"
  ])

}

# Creates GitHub's OIDC Provider in AWS IAM.
# URL identifies GitHub as the trusted OIDC token issuer.
# client_id_list sets sts.amazonaws.com as the token audience, allowing AWS STS to use the token for role assumption.
resource "aws_iam_openid_connect_provider" "github_oidc_provider" {
    url = "https://token.actions.githubusercontent.com"

    client_id_list = ["sts.amazonaws.com"]

    tags = {
        Name = "github-aws-oidc"
    }
}

# This role creates the trusted AWS identity that github actions can assukme using OIDC token.
# On conditions where trusted repo/branch and is intended for aws sts. 
# why aws sts cuz it is a service that allows you to request temporary, limited-privilege credentials for AWS IAM users or for users that you authenticate (federated users).
resource "aws_iam_role" "aws_oidc_role" {
    name = "github-aws-oidc-role"

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
                    StringLike = {
                        "token.actions.githubusercontent.com:sub" = local.github_oidc_subjects
                        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
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

                Resource = [
                    data.aws_ecr_repository.backend.arn,
                    data.aws_ecr_repository.frontend.arn
                ]
            }
        ]
    })
}

# Attach the policy to the iam role to allow to push images
resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
    role = aws_iam_role.aws_oidc_role.name
    policy_arn = aws_iam_policy.github_ecr_policy.arn
}


# output of role arn
output "aws_iam_role_arn" {
    value = aws_iam_role.aws_oidc_role.arn
} 
