# ============================================================================
# VPC
# ============================================================================

module "vpc" {
  source = "../../modules/vpc"

  aws_region = var.aws_region
  vpc_name   = var.vpc_name
  vpc_cidr   = var.vpc_cidr

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  rds_subnets     = var.rds_subnets

  need_ngw        = var.need_ngw
  need_single_ngw = var.need_single_ngw
}

# ============================================================================
# EKS
# ============================================================================

module "eks" {
  source = "../../modules/eks"

  cluster_name = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids

  endpoint_private_access = var.eks_cluster_endpoint_private_access
  endpoint_public_access  = var.eks_cluster_endpoint_public_access
  public_access_cidrs     = var.eks_cluster_public_access_cidrs

  cluster_service_ipv4_cidr = var.eks_cluster_service_ipv4_cidr

  enable_cluster_logs = var.eks_enable_cluster_logs
  cluster_log_types   = var.eks_cluster_log_types

  cluster_encryption_enabled = var.eks_cluster_encryption_enabled
  cluster_encryption_key_arn = aws_kms_key.eks_secrets.arn

  cluster_admin_role_arns = var.eks_cluster_admin_role_arns

  eks_nodes = var.eks_nodes
  ami_type  = var.eks_node_ami_type
}