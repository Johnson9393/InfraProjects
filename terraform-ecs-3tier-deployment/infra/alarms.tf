# -----------------------------------------------------------------------------
# CloudWatch Alarms
#
# Purpose:
# Creates CloudWatch Alarms for ECS and ALB metrics. When a threshold is
# breached, CloudWatch sends a notification to the configured SNS Topic.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name        = "${var.prefix}-${var.environment}-backend-cpu-high"
  alarm_description = "Backend ECS CPU utilization is above 80%."

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"

  statistic = "Average"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.dojo_cluster.name
    ServiceName = aws_ecs_service.dojo_service["backend"].name
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "backend_memory_high" {
  alarm_name        = "${var.prefix}-${var.environment}-backend-memory-high"
  alarm_description = "Backend ECS Memory utilization is above 80%."

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"

  statistic = "Average"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.dojo_cluster.name
    ServiceName = aws_ecs_service.dojo_service["backend"].name
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name        = "${var.prefix}-${var.environment}-frontend-cpu-high"
  alarm_description = "Frontend ECS CPU utilization is above 80%."

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"

  statistic = "Average"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.dojo_cluster.name
    ServiceName = aws_ecs_service.dojo_service["frontend"].name
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "frontend_memory_high" {
  alarm_name        = "${var.prefix}-${var.environment}-frontend-memory-high"
  alarm_description = "Frontend ECS Memory utilization is above 80%."

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"

  statistic = "Average"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.dojo_cluster.name
    ServiceName = aws_ecs_service.dojo_service["frontend"].name
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_response_time_high" {
  alarm_name        = "${var.prefix}-${var.environment}-alb-response-time-high"
  alarm_description = "ALB Target Response Time is above 3 seconds."

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"

  statistic = "Average"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 3
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer  = aws_alb.dojo_alb.arn_suffix
    TargetGroup = aws_alb_target_group.dojo_target_group.arn_suffix
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_target_4XX" {
  alarm_name        = "${var.prefix}-${var.environment}-alb-target-4xx"
  alarm_description = "ALB Target 4XX Errors is above threshold."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_4XX_Count"

  statistic = "Sum"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer  = aws_alb.dojo_alb.arn_suffix
    TargetGroup = aws_alb_target_group.dojo_target_group.arn_suffix
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5XX" {
  alarm_name        = "${var.prefix}-${var.environment}-alb-target-5xx"
  alarm_description = "ALB Target 5XX Errors is above threshold."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"

  statistic = "Sum"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer  = aws_alb.dojo_alb.arn_suffix
    TargetGroup = aws_alb_target_group.dojo_target_group.arn_suffix
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts_count" {
  alarm_name        = "${var.prefix}-${var.environment}-unhealthy-hosts"
  alarm_description = "Number of unhealthy hosts in the target group is above threshold."

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Maximum"
  period    = 60

  evaluation_periods  = 2 #CloudWatch waits for 2 consecutive 60-second periods before triggering to avoid short cpu spike
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer  = aws_alb.dojo_alb.arn_suffix
    TargetGroup = aws_alb_target_group.dojo_target_group.arn_suffix
  }
    # triggers emails when cpu is above 80% after 2 consecutive 60-second periods
  alarm_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]

    # It will trigger email when cpu back to normal 
  ok_actions = [
    aws_sns_topic.cloudwatch_alerts.arn
  ]
}









