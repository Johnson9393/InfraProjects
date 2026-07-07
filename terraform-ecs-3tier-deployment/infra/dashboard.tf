# -----------------------------------------------------------------------------
# CloudWatch Dashboard
#
# Purpose:
# Creates a production-style CloudWatch Dashboard to monitor the health and
# performance of the ECS application from a single place.
#
# Dashboard includes:
# - Backend CPU Utilization
# - Backend Memory Utilization
# - Frontend CPU Utilization
# - Frontend Memory Utilization
# - ALB Request Count
# - ALB Target Response Time
# - ALB Target 4XX Errors
# - ALB Target 5XX Errors
# - ALB Healthy Host Count
# - ALB UnHealthy Host Count
#
# Why these metrics?
# - CPU & Memory     -> Detect resource bottlenecks.
# - Request Count    -> Measure incoming traffic.
# - Response Time    -> Measure application latency.
# - 4XX Errors       -> Identify client-side request issues.
# - 5XX Errors       -> Identify server-side application failures.
# - Healthy Hosts    -> Verify ECS tasks are passing ALB health checks.
# - UnHealthy Hosts  -> Detect unhealthy ECS tasks during deployments or failures.
#
# This dashboard provides a single-pane view for monitoring application health
# during deployments, load testing, and production troubleshooting.
# -----------------------------------------------------------------------------


resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.prefix}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Backend CPU Utilization"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.dojo_cluster.name,
              "ServiceName",
              aws_ecs_service.dojo_service["backend"].name
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Backend Memory Utilization"
          region = var.aws_region
          stat   = "Average" #means the average of all the data points in the period
          period = 60

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.dojo_cluster.name,
              "ServiceName",
              aws_ecs_service.dojo_service["backend"].name
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "Frontend CPU Utilization"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.dojo_cluster.name,
              "ServiceName",
              aws_ecs_service.dojo_service["frontend"].name
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "Frontend Memory Utilization"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.dojo_cluster.name,
              "ServiceName",
              aws_ecs_service.dojo_service["frontend"].name
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "ALB Request Count"
          region = var.aws_region
          stat   = "Sum" #means the sum of all the data points in the period
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_alb.dojo_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target Response Time"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              aws_alb.dojo_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target 4XX Errors"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_4XX_Count",
              "LoadBalancer",
              aws_alb.dojo_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target 5XX Errors"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer",
              aws_alb.dojo_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 12
        height = 6

        properties = {
          title  = "Healthy Hosts"
          region = var.aws_region
          stat   = "Maximum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "LoadBalancer",
              aws_alb.dojo_alb.arn_suffix,
              "TargetGroup",
              aws_alb_target_group.dojo_target_group.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 24
        width  = 12
        height = 6

        properties = {
          title  = "UnHealthy Hosts"
          region = var.aws_region
          stat   = "Maximum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "UnHealthyHostCount",
              "LoadBalancer",
              aws_alb.dojo_alb.arn_suffix,
              "TargetGroup",
              aws_alb_target_group.dojo_target_group.arn_suffix
            ]
          ]
        }
      },
      #EMF widgets, Application Monitoring
      {
        type   = "metric"
        x      = 0
        y      = 30
        width  = 8
        height = 6

        properties = {
          title  = "Backend Request Duration Overall"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              local.backend_metric_namespace,
              "RequestDurationOverall",
              "Service",
              "backend"
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 30
        width  = 8
        height = 6

        properties = {
          title  = "API Request Duration"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              local.backend_metric_namespace,
              "RequestDuration"
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 16
        y      = 30
        width  = 8
        height = 6

        properties = {
          title  = "HTTP Request Count"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              local.backend_metric_namespace,
              "HttpRequestCount"
            ]
          ]
        }
      },

      # Log Metrics Widgets of Application
      {
        type   = "metric"
        x      = 0
        y      = 36
        width  = 8
        height = 6

        properties = {
          title  = "Backend 5XX Errors"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              local.backend_metric_namespace,
              "Backend5xxCount"
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 8
        y      = 36
        width  = 8
        height = 6

        properties = {
          title  = "Backend ERROR Logs"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              local.backend_metric_namespace,
              "BackendErrorCount"
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 36
        width  = 8
        height = 6

        properties = {
          title  = "Frontend Proxy Errors"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              local.backend_metric_namespace,
              "FrontendProxyErrorCount"
            ]
          ]
        }
      }
    ]
  })
}
