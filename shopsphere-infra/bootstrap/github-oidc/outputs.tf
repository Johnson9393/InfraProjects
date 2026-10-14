# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------

output "github_terraform_role_arn" {

  description = "IAM role ARN used by GitHub Actions for Terraform"

  value = aws_iam_role.github_terraform_role.arn
}

output "github_ecr_role_arn" {

  description = "IAM role ARN used by GitHub Actions for ECR image push"

  value = aws_iam_role.github_ecr_role.arn
}