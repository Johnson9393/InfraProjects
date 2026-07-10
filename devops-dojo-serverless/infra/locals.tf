locals {

  service_names = toset([
    "backend",
    "frontend"
  ])

  ecs_services = [

    merge(
      var.backend,
      {
        name            = "backend",
        container_name  = "${var.prefix}-backend-container",
        security_groups = [aws_security_group.backend_sg.id],
        image = "${aws_ecr_repository.ecr_repositories["backend"].repository_url}:${var.backend.image_tag}"
        environment = [
          {
            name  = "FLASK_DEBUG",
            value = "1"
          },
          {
            name  = "DATABASE_URL",
            value = aws_secretsmanager_secret_version.dojo_rds_secret_version.secret_string
          },
          {
            name  = "SECRET_KEY",
            value = random_password.backend_secret_key.result
          },
          {
            name  = "DB_HOST",
            value = local.db_host
          },
          {
            name  = "DB_PORT",
            value = "5432"
          },
          {
            name  = "DB_NAME",
            value = var.db_name
          },
          {
            name  = "DB_USERNAME",
            value = "postgres"
          },
          {
            name  = "DB_PASSWORD",
            value = random_password.rds_password.result
          },
          {
            name  = "ALLOWED_ORIGINS",
            value = "${var.sub_domain}.${var.domain_name}"
          }
        ]
      }
    ),

    merge(
      var.frontend,
      {
        name            = "frontend",
        container_name  = "${var.prefix}-frontend-container",
        security_groups = [aws_security_group.frontend_sg.id],
        image = "${aws_ecr_repository.ecr_repositories["frontend"].repository_url}:${var.frontend.image_tag}"
      }
    )
  ]

  #List of map will not work to iterate the items. Hence creating map to iterate thru services. Map or set works to iterate in terraform
  ecs_services_map = { for service in local.ecs_services : service.name => service }

  rds_connection_string = var.environment == "prod" ? "postgresql://${aws_rds_cluster.dojo_rds_cluster[0].master_username}:${random_password.rds_password.result}@${aws_rds_cluster.dojo_rds_cluster[0].endpoint}:${aws_rds_cluster.dojo_rds_cluster[0].port}/${aws_rds_cluster.dojo_rds_cluster[0].database_name}" : "postgresql://${aws_db_instance.dojo_rds_instance[0].username}:${random_password.rds_password.result}@${aws_db_instance.dojo_rds_instance[0].address}:${aws_db_instance.dojo_rds_instance[0].port}/${aws_db_instance.dojo_rds_instance[0].db_name}"

  db_host = var.environment == "prod" ? aws_rds_cluster.dojo_rds_cluster[0].endpoint : aws_db_instance.dojo_rds_instance[0].address

  backend_metric_namespace = "${var.environment}/${var.project}/Backend"
}


# Below is the prod grade approach to store secrets using json instead raw connection string

# locals {

#   rds_secret = jsonencode({
#     username = var.environment == "prod"
#       ? aws_rds_cluster.dojo_rds_cluster[0].master_username
#       : aws_db_instance.dojo_rds_instance[0].username

#     password = random_password.rds_password.result

#     host = var.environment == "prod"
#       ? aws_rds_cluster.dojo_rds_cluster[0].endpoint
#       : aws_db_instance.dojo_rds_instance[0].address

#     port = var.environment == "prod"
#       ? aws_rds_cluster.dojo_rds_cluster[0].port
#       : aws_db_instance.dojo_rds_instance[0].port

#     database = var.environment == "prod"
#       ? aws_rds_cluster.dojo_rds_cluster[0].database_name
#       : aws_db_instance.dojo_rds_instance[0].db_name

#     engine = "postgresql"
#   })

# }


# output "ecs_services_map" {
#   value     = local.ecs_services_map
#   sensitive = true
# }

resource "random_password" "backend_secret_key" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
