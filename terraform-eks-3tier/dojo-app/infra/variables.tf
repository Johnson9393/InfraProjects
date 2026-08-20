variable "env" {
    type = string
    description = "The environment name (e.g., dev, staging, prod)" 
    default = "dev"
}

variable "project" {
    type = string
    description = "The project name is devops dojo"
    default = "dojo"
}

variable "vpc_name" {
    type = string
    description = "The name of the VPC to use for the EKS cluster"
    default = "dojo-vpc"
}

variable "rds_subnets" {
  type = list(object({
    cidr              = string
    availability_zone = string
  }))

  default = [
    {
      cidr              = "10.0.5.0/24"
      availability_zone = "us-east-1a"
    },
    {
      cidr              = "10.0.6.0/24"
      availability_zone = "us-east-1b"
    }
  ]
}

