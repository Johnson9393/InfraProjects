# Iam role and policies for ECS task to pull images from ecr and write logs to cloudwatch
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.prefix}-${var.environment}-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Iam policy for ECS task execution role to pull images from ecr and write logs to cloudwatch
resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  name        = "${var.prefix}-${var.environment}-ecsTaskExecutionPolicy"
  description = "Policy for ECS task execution role to pull images from ecr and write logs to cloudwatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        # Resource = "${aws_cloudwatch_log_group.sp_log_group.arn}:*" # Only this specific log group can be accessed and write logs to cloudwatch
        Resource = "*" # We can create multiple policies by using each.key however since its a simple policy I am allowing all resources
        # Why : * here? Because we need to allow the task to create log streams and put log events in any log stream under the specified log group. The log group is defined as aws_cloudwatch_log_group.sp_log_group.arn, and the :* allows for any log stream within that log group to be accessed for creating log streams and putting log events.
      }
    ]
  })
}

# Attach policy to the role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
}