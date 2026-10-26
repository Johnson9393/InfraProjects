# One Amazon MQ RabbitMQ cluster for prod ShopSphere.
# CLUSTER_MULTI_AZ is three brokers in three AZs. AWS requires mq.m5.large
# for that mode. Dev skips this and keeps the in-cluster StatefulSet.

locals {
  amazonmq_amqps_endpoint = local.amazonmq_enabled ? try(aws_mq_broker.rabbitmq[0].instances[0].endpoints[0], "") : ""
  amazonmq_host = local.amazonmq_enabled ? element(
    split(":", replace(local.amazonmq_amqps_endpoint, "amqps://", "")),
    0
  ) : ""
}

# Using AMQPS where TLS is on thats why port is 5671 not 5672. 5672 is plain AMQP
resource "aws_security_group" "amazonmq" {
  count = local.amazonmq_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-rabbitmq"
  description = "AMQPS from the prod EKS cluster only"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id

  ingress {
    description     = "AMQPS from EKS"
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

resource "aws_mq_broker" "rabbitmq" {
  count = local.amazonmq_enabled ? 1 : 0

  broker_name        = "${var.env}-shopsphere-rabbitmq"
  engine_type        = "RabbitMQ"
  engine_version     = var.mq_engine_version
  host_instance_type = var.mq_instance_type
  deployment_mode    = "CLUSTER_MULTI_AZ"

  publicly_accessible        = false
  subnet_ids                 = data.aws_subnets.private[0].ids
  security_groups            = [aws_security_group.amazonmq[0].id]
  auto_minor_version_upgrade = true
  apply_immediately          = false

  encryption_options {
    use_aws_owned_key = true
  }

  logs {
    general = true
  }

  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "08:00"
    time_zone   = "UTC"
  }

  user {
    username = "rabbitmq_user"
    password = random_password.rabbitmq[var.env].result
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}
