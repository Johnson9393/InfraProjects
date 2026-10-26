# Creates one AWS Secrets Manager secret container for each ShopSphere secret.
resource "aws_secretsmanager_secret" "shopsphere" {
  for_each = local.secret_mappings

  name = "${var.env}/${each.key}"

  description = "ShopSphere ${var.env} secret: ${each.key}"

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

# Stores the generated secret values inside the corresponding AWS Secrets Manager secret.
# Prod DB secrets are written in secrets-rotation.tf so rotation can own the password.
resource "aws_secretsmanager_secret_version" "shopsphere" {
  for_each = {
    for key, value in local.secret_values : key => value
    if !local.rds_enabled || !contains(local.rds_app_secret_names, key)
  }

  secret_id = aws_secretsmanager_secret.shopsphere[each.key].id

  secret_string = jsonencode(each.value)
}