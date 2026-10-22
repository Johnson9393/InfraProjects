# ============================================================================
# General
# ============================================================================

aws_region = "us-east-1"
project    = "shopsphere"
env        = "prod"


# ============================================================================
# VPC
# ============================================================================

vpc_cidr = "10.1.0.0/16"

vpc_name = "prod-shopsphere-vpc"

enable_dns_hostnames = true
enable_dns_support   = true

public_subnets = [
  {
    cidr              = "10.1.1.0/24"
    availability_zone = "us-east-1a"
    prefix            = "public-1"
  },
  {
    cidr              = "10.1.2.0/24"
    availability_zone = "us-east-1b"
    prefix            = "public-2"
  }
]

private_subnets = [
  {
    cidr              = "10.1.11.0/24"
    availability_zone = "us-east-1a"
    prefix            = "private-1"
  },
  {
    cidr              = "10.1.12.0/24"
    availability_zone = "us-east-1b"
    prefix            = "private-2"
  }
]

rds_subnets = [
  {
    cidr              = "10.1.21.0/24"
    availability_zone = "us-east-1a"
    prefix            = "rds-1"
  },
  {
    cidr              = "10.1.22.0/24"
    availability_zone = "us-east-1b"
    prefix            = "rds-2"
  }
]

need_ngw        = true
need_single_ngw = true


# ============================================================================
# EKS
# ============================================================================

eks_cluster_name    = "prod-shopsphere"
eks_cluster_version = "1.35"

eks_cluster_endpoint_private_access = true
eks_cluster_endpoint_public_access  = true

eks_cluster_public_access_cidrs = [
  "0.0.0.0/0"
]

eks_cluster_service_ipv4_cidr = null

eks_enable_cluster_logs = true

eks_cluster_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]

eks_cluster_encryption_enabled = true

eks_cluster_admin_role_arns = [
  "arn:aws:iam::023192525105:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_5c1cd0f4738b46a6"
]


# ============================================================================
# EKS Node Groups
# ============================================================================

eks_nodes = {
  application = {
    instance_type      = "t3.medium"
    desired_size       = 3
    min_size           = 2
    max_size           = 5
    kubernetes_version = "1.35"
  }
}

eks_node_ami_type = "AL2023_x86_64_STANDARD"