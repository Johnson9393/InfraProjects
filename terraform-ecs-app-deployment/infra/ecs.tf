# Create ECS cluster which is a logical unit that contains the ECS services and tasks. ECS cluster means a logical grouping of tasks or services. You can have multiple clusters within a single region. Clusters may contain more than one type of instance, and you can use both Linux and Windows containers in your tasks.
resource "aws_ecs_cluster" "sp_cluster" {
  name = var.ecs_cluster_name

  # setting {
  #     name  = "containerInsights"
  #     value = "enabled"
  # }
}

# ECS Task definition is a json file that describes one or more containers (up to a maximum of ten) that form your application. The task definition is used to run an individual task or create a service. It can be thought of as a blueprint for your application. It specifies various parameters for the application, such as which Docker images to use for the containers, how much CPU and memory to allocate, and which ports to expose.
resource "aws_ecs_task_definition" "sp_task_definition" {
  family                   = var.ecs_task_def
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"

  container_definitions = jsonencode([
    {
      name      = var.ecs_container_name
      image     = var.sp_app_image
      essential = true
      portMappings = [
        {
          containerPort = var.sp_app_port
          hostPort      = var.sp_app_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DB_LINK"
          value = aws_secretsmanager_secret_version.sp_rds_secret_version.secret_string
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.cloudwatch_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

# ECS Service is a long-running task that you can run and maintain on an ECS cluster. It allows you to run and maintain a specified number of instances of a task definition simultaneously in an ECS cluster. If any of the tasks fail or stop, the service scheduler will automatically replace them to maintain the desired count.
resource "aws_ecs_service" "sp_service" {
  name            = var.ecs_service
  cluster         = aws_ecs_cluster.sp_cluster.id
  task_definition = aws_ecs_task_definition.sp_task_definition.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_alb_target_group.sp_target_group.arn
    container_name   = var.ecs_container_name
    container_port   = var.sp_app_port
  }

  network_configuration {
    subnets          = [aws_subnet.sp_private_subnet_1.id, aws_subnet.sp_private_subnet_2.id]
    security_groups  = [aws_security_group.sp_ecs_sg.id]
    assign_public_ip = false
  }

  depends_on = [aws_alb_listener.sp_http_listener]

}

#####################################################
# ECS Service Auto Scaling Target
#
# Enables ECS Service Auto Scaling.
# ECS can increase/decrease the number of running tasks.
#
# Min Tasks = 1
# Max Tasks = 4
#
# Example:
# CPU Low  -> 1 Task
# CPU High -> 2,3,4 Tasks
#####################################################

resource "aws_appautoscaling_target" "sp_target" {
  min_capacity = 1
  max_capacity = 4

  # ECS Service to be scaled
  resource_id = "service/${aws_ecs_cluster.sp_cluster.name}/${aws_ecs_service.sp_service.name}" # Identifies which ecs service to be scaled. Meaning service/sp-cluster/sp-service. Scale THIS servic inside THIS cluster

  scalable_dimension = "ecs:service:DesiredCount" # what property should be changed when auto scaling
  service_namespace  = "ecs" # which service to be scaled. Here its ecs service. 
}

#####################################################
# CPU Target Tracking Scaling Policy
#
# AWS automatically maintains CPU around 60%.
#
# Example:
# CPU > 60%  -> Add Tasks
# CPU < 60%  -> Remove Tasks
#
# Scale Out:
# Wait only 60 sec before adding tasks.
#
# Scale In:
# Wait 300 sec before removing tasks.
# (Prevents aggressive scale down)
#####################################################

resource "aws_appautoscaling_policy" "sp_cpu_policy" {
  name               = "cpu-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sp_target.resource_id
  scalable_dimension = aws_appautoscaling_target.sp_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.sp_target.service_namespace

  target_tracking_scaling_policy_configuration {

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    # Maintain CPU around 60%
    target_value = 60.0

    # Wait 60 sec before scaling out
    scale_out_cooldown = 60

    # Wait 300 sec before scaling in
    scale_in_cooldown = 300
  }
}


#####################################################
# Memory Step Scaling Policy
#
# Step Scaling performs fixed scaling actions.
#
# Example:
# Memory crosses threshold
# -> Add 1 Task
#
# Unlike Target Tracking,
# Step Scaling requires CloudWatch Alarms.
#
# NOTE:
# This policy alone will NOT work.
# You must create CloudWatch alarms
# and attach them to this policy.
#####################################################
# We will learn more of step scaling during python projects 

resource "aws_appautoscaling_policy" "sp_memory_policy" {
  name               = "memory-tracking"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.sp_target.resource_id
  scalable_dimension = aws_appautoscaling_target.sp_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.sp_target.service_namespace

  step_scaling_policy_configuration {

    step_adjustment {
      # Add 1 task when alarm creates with memory util at 80% 
      # metric intervals are how far the metric is beyond 80%. Means if its 80 to 90% add 1 task
      # Realistic example is add 2 more scaling_adjustments with lower to 10 and upper to 20. another adjustemnt with lower bound 20. 
      # 80% - 90%  -> Add 1 Task
      # 90% - 100% -> Add 2 Tasks
      # >100%      -> Add 3 Tasks
      scaling_adjustment = 1

      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 10
    }
  }
}