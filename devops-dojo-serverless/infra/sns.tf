# -----------------------------------------------------------------------------
# SNS Notifications
#
# Purpose:
# Creates an SNS Topic and Email Subscription to receive CloudWatch Alarm
# notifications. Whenever a configured alarm enters the ALARM state, CloudWatch
# publishes a message to the SNS Topic, which then sends an email notification.
#
# Flow:
#
# CloudWatch Alarm
#        │
#        ▼
#     SNS Topic
#        │
#        ▼
# Email Notification
#
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "cloudwatch_alerts" {
  name = "${var.prefix}-${var.environment}-alerts"

  tags = {
    Name = "${var.prefix}-${var.environment}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cloudwatch_alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}