# Exposes the ECR repository URIs for use by deployment configuration.
output "ecr_repository_urls" {
  description = "ECR repository URLs for all ShopSphere application components."

  value = {
    for name, repository in aws_ecr_repository.this :
    name => repository.repository_url
  }
}