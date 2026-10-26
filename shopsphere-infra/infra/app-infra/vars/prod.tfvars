env                      = "prod"
enable_eso_secrets       = true
enable_cluster_resources = true

platform_env   = "prod"
alb_group_name = "shopsphere-prod-alb"

storage_class = "gp3"

# In-cluster Redis stays off. Prod uses ElastiCache in elasticache-redis.tf.
redis_enabled = false