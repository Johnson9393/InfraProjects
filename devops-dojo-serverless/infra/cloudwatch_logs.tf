# -----------------------------------------------------------------------------
# CloudWatch Log Metric Filters
#
# Purpose:
# Converts application log patterns into CloudWatch Metrics, which can be used
# in Dashboards and CloudWatch Alarms.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "backend_5xx" {
  name           = "${var.prefix}-${var.environment}-backend-5xx"
  log_group_name = aws_cloudwatch_log_group.dojo_log_group["backend"].name

  # Matches any backend log where the HTTP response status is 5XX.
  pattern = "{ $.status >= 500 }"

  metric_transformation {
    namespace = local.backend_metric_namespace
    name      = "Backend5xxCount"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "backend_errors" {
  name           = "${var.prefix}-${var.environment}-backend-errors"
  log_group_name = aws_cloudwatch_log_group.dojo_log_group["backend"].name

  # Matches backend logs with ERROR log level.
  pattern = "{ $.levelname = \"ERROR\" }"

  metric_transformation {
    namespace = local.backend_metric_namespace
    name      = "BackendErrorCount"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "frontend_proxy_errors" {
  name           = "${var.prefix}-${var.environment}-frontend-proxy-errors"
  log_group_name = aws_cloudwatch_log_group.dojo_log_group["frontend"].name

  # Matches frontend proxy failures while communicating with the backend.
  pattern = "Proxy error"

  metric_transformation {
    namespace = local.backend_metric_namespace
    name      = "FrontendProxyErrorCount"
    value     = "1"
  }
}