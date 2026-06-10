variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region where the resources will be created"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr_blocks" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "rds_subnet_cidr_blocks" {
  type    = list(string)
  default = ["10.0.5.0/24", "10.0.6.0/24"]
}


variable "ecs_cluster_name" {
  type    = string
  default = "sp-cluster"
}

variable "ecs_task_def" {
  type    = string
  default = "sp-task-def"
}

variable "ecs_container_name"{
  type    = string
  default = "sp-container"
}

variable "sp_app_image" {
  type   = string
  default = "023192525105.dkr.ecr.us-east-1.amazonaws.com/student-portal:1.0"
}

variable "sp_app_port" {
  type    = number
  default = 8000
}

variable "cloudwatch_log_group_name" {
  type    = string
  default = "/ecs/sp-app-logs"
}

variable "alb_name" {
  type    = string
  default = "sp-alb"
}

variable "domain_name" {
  type    = string
  default = "infralabx.space"
}