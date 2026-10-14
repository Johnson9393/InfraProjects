# Defines environment-specific names for Kubernetes platform resources.
locals {
  env_prefix       = "${var.env}-"
  eks_cluster_name = "${local.env_prefix}${var.eks_cluster_name}"
  eso_namespace    = "${local.env_prefix}eso"
  cnpg_namespace   = "${local.env_prefix}${var.cnpg_namespace}"
}