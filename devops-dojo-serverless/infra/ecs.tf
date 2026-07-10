# namespace for cluster
resource "aws_service_discovery_http_namespace" "dojo_namespace" {
  name        = "${var.prefix}-${var.environment}-namespace"
  description = "HTTP namespace for secure ECS Service Connect mesh"
}

# Cluster
resource "aws_ecs_cluster" "dojo_cluster" {
  name = "${var.prefix}-${var.environment}-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.dojo_namespace.arn
  }

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}


# ECS-Task-Definition

resource "aws_ecs_task_definition" "dojo_task_definition" {
  for_each                 = local.ecs_services_map
  family                   = "${var.prefix}-${var.environment}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory

  container_definitions = jsonencode([
    {
      name      = each.value.container_name
      image     = each.value.image
      essential = true
      portMappings = [
        {
          containerPort = each.value.port
          name          = each.value.port_name
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]
      environment = each.value.environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dojo_log_group[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}


# ECS Services. 
resource "aws_ecs_service" "dojo_service" {
  for_each        = local.ecs_services_map
  name            = "${var.prefix}-${var.environment}-${each.key}-service"
  cluster         = aws_ecs_cluster.dojo_cluster.id
  task_definition = aws_ecs_task_definition.dojo_task_definition[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  dynamic "load_balancer" {
    for_each = each.value.need_alb ? [1] : []
    content {
      target_group_arn = aws_alb_target_group.dojo_target_group.arn
      container_name   = each.value.container_name
      container_port   = each.value.port
    }

  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.dojo_namespace.http_name
    service {
      port_name = each.value.port_name
      client_alias {
        port     = each.value.port
        dns_name = each.value.port_name
      }
    }
  }

  network_configuration {
    subnets          = module.network.private_subnet_ids
    security_groups  = each.value.security_groups
    assign_public_ip = false
  }

  depends_on = [aws_alb_listener.dojo_http_listener]

}


