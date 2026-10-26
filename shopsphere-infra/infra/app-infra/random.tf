# Generates independent credentials for each selected environment using for_each.
# Example: random_password.db["dev"] creates a separate Dev DB password, while UAT/Prod get their own independent passwords.
resource "random_password" "db" {
  for_each = local.secret_envs

  length  = 24
  special = false
}

# One password per prod Aurora app user. Dest still uses random_password.db.
resource "random_password" "rds_app" {
  for_each = local.rds_enabled ? local.rds_app_secret_names : toset([])

  length  = 24
  special = false
}

# Generates one independent Redis password for each environment.
resource "random_password" "redis" {
  for_each = local.secret_envs

  length  = 24
  special = false
}

# Generates one independent RabbitMQ password for each environment.
resource "random_password" "rabbitmq" {
  for_each = local.secret_envs

  length  = 24
  special = false
}

# Generates one independent JWT secret for each environment.
resource "random_password" "jwt" {
  for_each = local.secret_envs

  length  = 48
  special = false
}