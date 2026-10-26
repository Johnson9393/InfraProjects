# One ElastiCache Redis system for prod ShopSphere.
# Primary plus replica in two AZs. Dev skips this and keeps the in-cluster Redis pod.
# Cart service talks to the primary endpoint. The replica is for failover.

resource "aws_security_group" "elasticache_redis" {
  count = local.elasticache_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-redis"
  description = "Redis from the prod EKS cluster only"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id

  ingress {
    description     = "Redis from EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

# Subnet group is not Redis. It is the list of private subnets ElastiCache may use.
# Private subnets already span us-east-1a and us-east-1b.
resource "aws_elasticache_subnet_group" "redis" {
  count = local.elasticache_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-redis"
  description = "Private subnets for prod ShopSphere Redis"
  subnet_ids  = data.aws_subnets.private[0].ids

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count = local.elasticache_enabled ? 1 : 0

  replication_group_id = "${var.env}-shopsphere-redis"
  description          = "Prod ShopSphere Redis for cart"
  engine               = "redis"
  engine_version       = var.elasticache_engine_version
  node_type            = var.elasticache_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.redis[0].name
  security_group_ids = [aws_security_group.elasticache_redis[0].id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis[var.env].result

  snapshot_retention_limit = 1
  snapshot_window          = "07:00-08:00"
  maintenance_window       = "sun:08:00-sun:09:00"

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}
