variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "devopsdojo"
}

variable "environment" {
  type = string
}

variable "prefix" {
  type    = string
  default = "dojo"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
}

variable "private_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
}

variable "rds_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
}

variable "frontend" {
  type = object({
    image_tag     = string
    port          = number
    port_name     = string
    cpu           = number
    memory        = number
    need_alb      = bool
    desired_count = number
    environment = list(object({
      name  = string
      value = string
    }))
  })
  description = "Frontend service configuration"
}

variable "backend" {
  type = object({
    image_tag     = string
    port          = number
    port_name     = string
    cpu           = number
    memory        = number
    need_alb      = bool
    desired_count = number
  })
  description = "backend service configuration"
}

variable "domain_name" {
  type    = string
  default = "infralabx.space"
}


variable "sub_domain" {
  type    = string
  default = "dojo"
}

variable "db_name" {
  description = "Application database name"
  type        = string
}

variable "rds_instance_config" {
  type = object({
    engine                  = string
    instance_class          = string
    username                = string
    allocated_storage       = number
    backup_retention_period = number
    publicly_accessible     = bool
    skip_final_snapshot     = bool
    apply_immediately       = bool
  })

  description = "RDS instance configuartion"
}

variable "aurora_cluster_config" {
  description = "Aurora cluster configuration"

  type = object({
    engine                  = string
    engine_version          = string
    master_username         = string
    backup_retention_period = number
    preferred_backup_window = string
    storage_encrypted       = bool
  })
}

variable "aurora_instance_config" {
  description = "Aurora writer and reader configuration"

  type = object({
    instance_class      = string
    ca_cert_identifier  = string
    apply_immediately   = bool
    publicly_accessible = bool
  })
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications."
  type        = string
  default = "johnson.johnny0903@gmail.com"
}
