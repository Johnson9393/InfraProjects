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
  name            = "sp-service"
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

}
