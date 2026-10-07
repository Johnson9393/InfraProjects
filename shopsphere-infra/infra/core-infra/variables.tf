# ============================================================================
# General
# ============================================================================

variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Deployment environment"
  type        = string
}


# ============================================================================
# VPC
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
}

variable "public_subnets" {
  description = "List of public subnet configurations"

  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
}

variable "private_subnets" {
  description = "List of private subnet configurations"

  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
}

variable "rds_subnets" {
  description = "List of RDS subnet configurations"

  type = list(object({
    cidr              = string
    availability_zone = string
    prefix            = string
  }))
}

variable "need_ngw" {
  description = "Whether NAT Gateway is required"
  type        = bool
}

variable "need_single_ngw" {
  description = "Whether to use a single NAT Gateway"
  type        = bool
}


# ============================================================================
# EKS
# ============================================================================

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_cluster_endpoint_private_access" {
  description = "Enable private access to the EKS API endpoint"
  type        = bool
}

variable "eks_cluster_endpoint_public_access" {
  description = "Enable public access to the EKS API endpoint"
  type        = bool
}

variable "eks_cluster_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  type        = list(string)
}

variable "eks_cluster_service_ipv4_cidr" {
  description = "IPv4 CIDR block used for Kubernetes Services"
  type        = string
}

variable "eks_enable_cluster_logs" {
  description = "Enable EKS control plane logging"
  type        = bool
}

variable "eks_cluster_log_types" {
  description = "EKS control plane log types to enable"
  type        = list(string)
}

variable "eks_cluster_encryption_enabled" {
  description = "Enable envelope encryption for Kubernetes Secrets"
  type        = bool
}

variable "eks_cluster_admin_role_arns" {
  description = "IAM role ARNs that receive EKS cluster administrator access"
  type        = list(string)
}


# ============================================================================
# EKS Node Groups
# ============================================================================

variable "eks_nodes" {
  description = "EKS managed node groups"

  type = map(object({
    instance_type      = string
    desired_size       = number
    min_size           = number
    max_size           = number
    kubernetes_version = string
  }))
}

variable "eks_node_ami_type" {
  description = "AMI type for EKS managed node groups"
  type        = string
}