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
