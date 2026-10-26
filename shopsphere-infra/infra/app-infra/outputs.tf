# Exposes the ECR repository URIs for use by deployment configuration.
output "ecr_repository_urls" {
  description = "ECR repository URLs for all ShopSphere application components."

  value = {
    for name, repository in aws_ecr_repository.this :
    name => repository.repository_url
  }
}

output "elasticache_redis_primary_endpoint" {
  description = "Prod ElastiCache Redis primary hostname. Use this as REDIS_HOST."
  value       = local.elasticache_enabled ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
}

output "elasticache_redis_reader_endpoint" {
  description = "Prod ElastiCache Redis reader hostname."
  value       = local.elasticache_enabled ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
}

output "amazonmq_rabbitmq_host" {
  description = "Prod Amazon MQ RabbitMQ hostname. Use this as RABBITMQ_HOST."
  value       = local.amazonmq_enabled ? local.amazonmq_host : null
}

output "amazonmq_rabbitmq_amqps_endpoint" {
  description = "Prod Amazon MQ AMQPS endpoint including scheme and port."
  value       = local.amazonmq_enabled ? local.amazonmq_amqps_endpoint : null
}

# Exposes ECR repository names for the GitHub OIDC bootstrap.
# Reference this output when configuring the OIDC IAM policy to
# restrict GitHub Actions image-push permissions to repositories
# actually created by App Infra for the selected environment.
output "ecr_repository_names" {
  description = "ECR repository names for the selected environment"
  value       = [for repository in aws_ecr_repository.this : repository.name]
}