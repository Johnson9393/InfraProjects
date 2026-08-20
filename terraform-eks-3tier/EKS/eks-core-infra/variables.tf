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

variable "cluster_version" {
    description = "The Kubernetes version for the EKS cluster"
    type        = string
    default     = "1.34"
}

variable "vpc_cidr" {
    description = "The CIDR block for the VPC"
    type        = string
    default     = "10.0.0.0/16"
}

variable "vpc_name" {
    description = "The name of the VPC"
    type        = string
    default     = "dojo-vpc"
}

variable "need_1_ngw" {
    description = "Whether to create a single NAT Gateway (true) or multiple NAT Gateways (false)"
    type        = bool
    default     = true
}

variable "public_subnet_cidrs" {
    description = "The CIDR blocks for the public subnets"
    type        = list(string)
    default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
    description = "The CIDR blocks for the private subnets"
    type        = list(string)
    default     = ["10.0.3.0/24", "10.0.4.0/24"]
}


