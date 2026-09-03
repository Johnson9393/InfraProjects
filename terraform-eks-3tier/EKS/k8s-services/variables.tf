variable "env" {
    description = "The environment for the EKS cluster (e.g., dev, staging, prod)"
    type        = string
    default    = "dev"
}

variable "project" {
    description = "The project name for the EKS cluster is student portal"
    type        = string
    default     = "dojo"
}

variable "region" {
    description = "The AWS region where the EKS cluster will be created"
    type        = string
    default     = "us-east-1"
}

variable "cluster_name" {
    description = "The name of the EKS cluster"
    type        = string
    default     = "dojo-eks"
}

variable "vpc_name" {
    type = string
    description = "The name of the VPC to use for the EKS cluster"
    default = "dojo-vpc"
}

variable "awsloadbalancercontroller_sa" {
  default = "aws-load-balancer-controller"
}