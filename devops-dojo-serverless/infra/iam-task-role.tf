# This is ecs task role and role policy for ECS backend task to upload file to s3 bucket and write logs to cloudwatch

resource "aws_iam_role" "ecs_task_role" {

  name = "${var.prefix}-${var.environment}-ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_policy" "ecs_task_s3_policy" {

  name = "${var.prefix}-${var.environment}-ecsTaskS3Policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          "arn:aws:s3:::devopsdojo-transaction-files-dev"
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "arn:aws:s3:::devopsdojo-transaction-files-dev/*"
        ]
      }

    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attachment" {

  role = aws_iam_role.ecs_task_role.name

  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}