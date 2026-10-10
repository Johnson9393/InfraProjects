# Defines environment-specific names for Kubernetes platform resources.
locals {
  env_prefix = "${var.env}-"

  # Resolves the name of the existing EKS cluster.
  eks_cluster_name = "${local.env_prefix}${var.eks_cluster_name}"

  # Defines the dedicated namespace for the External Secrets Operator.
  eso_namespace = "${local.env_prefix}eso"
}