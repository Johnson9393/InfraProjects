# One RDS admin secret per environment (prod now, QA later with the same code).
# This is for you: tunnel + Postgres app.
# Dev skips this. App services do not use this login.

resource "aws_secretsmanager_secret" "rds" {
  count = local.rds_enabled ? 1 : 0

  name        = "${var.env}/shopsphere-rds"
  description = "ShopSphere ${var.env} Aurora admin connection"

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

resource "aws_secretsmanager_secret_version" "rds" {
  count = local.rds_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.rds[0].id

  secret_string = jsonencode({
    username    = aws_rds_cluster.shopsphere[0].master_username
    password    = random_password.db[var.env].result
    host        = aws_rds_cluster.shopsphere[0].endpoint
    reader_host = aws_rds_cluster.shopsphere[0].reader_endpoint
    proxy_host  = aws_db_proxy.shopsphere[0].endpoint
    port        = aws_rds_cluster.shopsphere[0].port
    dbname      = aws_rds_cluster.shopsphere[0].database_name
    engine      = "aurora-postgresql"
  })
}