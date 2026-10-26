# RDS Proxy in front of the one prod Aurora cluster.
# Dev skips this. Helm still uses the raw Aurora host until we switch it later.

resource "aws_security_group" "rds_proxy" {
  count = local.rds_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-rds-proxy"
  description = "Pods to RDS Proxy only"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id

  ingress {
    description     = "Postgres from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  egress {
    description     = "Postgres to Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds[0].id]
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

# Aurora also accepts connections from the proxy, not only from EKS.
resource "aws_security_group_rule" "rds_from_proxy" {
  count = local.rds_enabled ? 1 : 0

  type                     = "ingress"
  description              = "Postgres from RDS Proxy"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds[0].id
  source_security_group_id = aws_security_group.rds_proxy[0].id
}

resource "aws_iam_role" "rds_proxy" {
  count = local.rds_enabled ? 1 : 0

  name = "${var.env}-shopsphere-rds-proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "rds_proxy" {
  count = local.rds_enabled ? 1 : 0

  name = "${var.env}-shopsphere-rds-proxy-secrets"
  role = aws_iam_role.rds_proxy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.shopsphere["product-db-credentials"].arn,
          aws_secretsmanager_secret.shopsphere["user-db-credentials"].arn,
          aws_secretsmanager_secret.shopsphere["order-db-credentials"].arn,
          aws_secretsmanager_secret.shopsphere["payment-db-credentials"].arn,
        ]
      }
    ]
  })
}

resource "aws_db_proxy" "shopsphere" {
  count = local.rds_enabled ? 1 : 0

  name                   = "${var.env}-shopsphere"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.rds_proxy[0].arn
  vpc_subnet_ids         = data.aws_subnets.rds[0].ids
  vpc_security_group_ids = [aws_security_group.rds_proxy[0].id]
  require_tls            = true

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.shopsphere["product-db-credentials"].arn
  }

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.shopsphere["user-db-credentials"].arn
  }

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.shopsphere["order-db-credentials"].arn
  }

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.shopsphere["payment-db-credentials"].arn
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

resource "aws_db_proxy_default_target_group" "shopsphere" {
  count = local.rds_enabled ? 1 : 0

  db_proxy_name = aws_db_proxy.shopsphere[0].name

  connection_pool_config {
    max_connections_percent      = 90
    max_idle_connections_percent = 50
    connection_borrow_timeout    = 120
  }
}

resource "aws_db_proxy_target" "shopsphere" {
  count = local.rds_enabled ? 1 : 0

  db_proxy_name         = aws_db_proxy.shopsphere[0].name
  target_group_name     = aws_db_proxy_default_target_group.shopsphere[0].name
  db_cluster_identifier = aws_rds_cluster.shopsphere[0].id
}