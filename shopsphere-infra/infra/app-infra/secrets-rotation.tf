# Weekly Aurora password rotation on prod only.
# Dest skips this: CNPG is not RDS, so the AWS rotator cannot talk to it.
#
# Flow:
#   1. AWS Secrets Manager calls the official PostgreSQL rotation Lambda every 7 days.
#   2. The Lambda connects to the Aurora writer (not the proxy) and ALTER USER.
#   3. It writes the new password into the same secret.
#   4. RDS Proxy re-reads the secret. ESO copies username/password every hour.
#   5. Reloader restarts the pods.
#
# rotate_immediately is false so apply does not rotate before the SQL users exist.

data "aws_partition" "current" {}

data "aws_subnets" "private" {
  count = local.rds_enabled ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.cluster.vpc_config[0].vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.env}-shopsphere-vpc-private-*"]
  }
}

locals {
  rds_app_secret_payloads = local.rds_enabled ? {
    "product-db-credentials" = {
      username            = "product_user"
      password            = random_password.rds_app["product-db-credentials"].result
      engine              = "postgres"
      host                = aws_rds_cluster.shopsphere[0].endpoint
      port                = aws_rds_cluster.shopsphere[0].port
      dbname              = "products"
      dbClusterIdentifier = aws_rds_cluster.shopsphere[0].cluster_identifier
    }

    "user-db-credentials" = {
      username            = "user_user"
      password            = random_password.rds_app["user-db-credentials"].result
      engine              = "postgres"
      host                = aws_rds_cluster.shopsphere[0].endpoint
      port                = aws_rds_cluster.shopsphere[0].port
      dbname              = "users"
      dbClusterIdentifier = aws_rds_cluster.shopsphere[0].cluster_identifier
    }

    "order-db-credentials" = {
      username            = "order_user"
      password            = random_password.rds_app["order-db-credentials"].result
      engine              = "postgres"
      host                = aws_rds_cluster.shopsphere[0].endpoint
      port                = aws_rds_cluster.shopsphere[0].port
      dbname              = "orders"
      dbClusterIdentifier = aws_rds_cluster.shopsphere[0].cluster_identifier
    }

    "payment-db-credentials" = {
      username            = "payment_user"
      password            = random_password.rds_app["payment-db-credentials"].result
      engine              = "postgres"
      host                = aws_rds_cluster.shopsphere[0].endpoint
      port                = aws_rds_cluster.shopsphere[0].port
      dbname              = "payments"
      dbClusterIdentifier = aws_rds_cluster.shopsphere[0].cluster_identifier
    }
  } : {}
}

# First write of the four app secrets. After that, rotation owns the password.
resource "aws_secretsmanager_secret_version" "rds_app" {
  for_each = local.rds_app_secret_payloads

  secret_id     = aws_secretsmanager_secret.shopsphere[each.key].id
  secret_string = jsonencode(each.value)

  lifecycle {
    ignore_changes = [secret_string] # ignore_changes tells Terraform not to put that old password back. It skips secret_string on later applies, so the new password stays in Secrets Manager.
  }
}

# Lambda lives on private subnets (NAT) so it can reach Secrets Manager.
# RDS subnets have no NAT, so we do not put the function there.
resource "aws_security_group" "secrets_rotation" {
  count = local.rds_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-secrets-rotation"
  description = "Secrets Manager rotator to Aurora"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id

  egress {
    description     = "Postgres to Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds[0].id]
  }

  egress {
    description = "HTTPS to Secrets Manager via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

resource "aws_security_group_rule" "rds_from_rotation" {
  count = local.rds_enabled ? 1 : 0

  type                     = "ingress"
  description              = "Postgres from Secrets Manager rotator"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds[0].id
  source_security_group_id = aws_security_group.secrets_rotation[0].id
}

# Official AWS single-user PostgreSQL rotator (same one CDK uses).
resource "aws_serverlessapplicationrepository_cloudformation_stack" "pg_rotation" {
  count = local.rds_enabled ? 1 : 0

  name             = "${var.env}-shopsphere-pg-rotation"
  application_id   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  semantic_version = "1.1.618"
  capabilities     = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    functionName        = "${var.env}-shopsphere-pg-rotation"
    endpoint            = "https://secretsmanager.${var.region}.${data.aws_partition.current.dns_suffix}"
    vpcSubnetIds        = join(",", data.aws_subnets.private[0].ids)
    vpcSecurityGroupIds = aws_security_group.secrets_rotation[0].id
  }
}

# Secret rotation for four db's in prod
resource "aws_secretsmanager_secret_rotation" "rds_app" {
  for_each = local.rds_app_secret_payloads

  secret_id           = aws_secretsmanager_secret.shopsphere[each.key].id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.pg_rotation[0].outputs.RotationLambdaARN
  rotate_immediately  = false

  rotation_rules {
    automatically_after_days = 7
  }

  depends_on = [aws_secretsmanager_secret_version.rds_app]
}

# secret rotation for cluster DB admin in prod
resource "aws_secretsmanager_secret_rotation" "rds_admin" {
  count = local.rds_enabled ? 1 : 0

  secret_id           = aws_secretsmanager_secret.rds[0].id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.pg_rotation[0].outputs.RotationLambdaARN
  rotate_immediately  = false

  rotation_rules {
    automatically_after_days = 7
  }

  depends_on = [aws_secretsmanager_secret_version.rds]
}