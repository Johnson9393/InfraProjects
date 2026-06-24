# Cloud watch log group for the application
resource "aws_cloudwatch_log_group" "dojo_log_group" {
  for_each          = local.ecs_services_map
  name              = "${var.prefix}-${var.environment}-${each.key}"
  retention_in_days = 7

  tags = {
    Name = "ecs/${var.prefix}-${var.environment}-${each.key}"
  }
}
