variable "aws_region" {
    type = string
    default = "us-east-1"
}

variable "project" {
    type = string
    default = "DevopsDojo"
}

variable "environment" {
    type = string
}

variable "prefix" {
    type = string
    default = "dojo"
}

variable "vpc_cidr" {
    type = string
    default = "10.0.0.0/16"
}

variable "public_subnets" {
    type = list(object({
        cidr = string
        availability_zone = string
        prefix = string
    }))
}

variable "private_subnets" {
    type = list(object({
        cidr = string
        availability_zone = string
        prefix = string
    }))
}

variable "rds_subnets" {
    type = list(object({
        cidr = string
        availability_zone = string
        prefix = string
    }))
}
