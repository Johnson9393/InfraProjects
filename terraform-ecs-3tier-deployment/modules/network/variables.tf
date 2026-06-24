# vpc  cidr
variable "vpc_cidr" {
  type        = string
  description = "cidr for vpc "
}

# Allows instances and resources in the VPC to receive DNS hostnames, making it easier for services to communicate using names instead of IP addresses.
variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in the VPC"
  default     = true
}

# Enables the AWS-provided DNS server inside the VPC, allowing resources to resolve domain names (such as AWS service endpoints, RDS endpoints, and internal hostnames) into IP addresses.
variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy the resources"
}

# vpc_name
variable "vpc_name" {
  type        = string
  description = "name of vpc"
}


variable "private_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
  description = "List of private subnets"

  validation {
    condition = (var.need_single_ngw || length(var.private_subnets) == length(var.public_subnets))

    error_message = "When using multiple NAT Gateways, public and private subnet counts must be equal."
  }
}

variable "public_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
  description = "List of public subnets"
}

variable "rds_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
  description = "list of rds subnets"
}

variable "need_ngw" {
  type        = bool
  description = "If ngw is required"
}

variable "need_single_ngw" {
  type        = bool
  description = "need only 1 ngw"
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags to apply to the resources"
  default = {
    managed_by  = "terraform",
    module_name = "network"
  }
}
