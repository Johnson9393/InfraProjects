# Exposes the ECR repository URIs for use by deployment configuration.
output "ecr_repository_urls" {
  description = "ECR repository URLs for all ShopSphere application components."

  value = {
    for name, repository in aws_ecr_repository.this :
    name => repository.repository_url
  }
}

# Exposes ECR repository names for the GitHub OIDC bootstrap.
# Reference this output when configuring the OIDC IAM policy to
# restrict GitHub Actions image-push permissions to repositories
# actually created by App Infra for the selected environment.
output "ecr_repository_names" {
  description = "ECR repository names for the selected environment"
  value       = [for repository in aws_ecr_repository.this : repository.name]
}