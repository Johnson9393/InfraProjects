# Cloud watch log group for the application
resource "aws_cloudwatch_log_group" "sp_log_group" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 7

  tags = {
    Name = var.cloudwatch_log_group_name
  }
}