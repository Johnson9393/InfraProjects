# Defines environment-specific names for Kubernetes platform resources.
locals {
  env_prefix       = "${var.env}-"
  eks_cluster_name = "${local.env_prefix}${var.eks_cluster_name}"
  env_dns_suffix   = "${var.env}.${var.domain_name}"
  platform_env     = var.platform_env
  eso_namespace    = "${local.env_prefix}eso"
  cnpg_namespace   = "${local.env_prefix}${var.cnpg_namespace}"

  argocd_namespace     = "${local.env_prefix}argocd"
  monitoring_namespace = "${local.env_prefix}monitoring"

  deploy_acm        = var.env == local.platform_env
  deploy_argocd     = coalesce(var.enable_argocd, var.env == local.platform_env)
  deploy_monitoring = coalesce(var.enable_monitoring, var.env == local.platform_env)

  acm_cert_arn = local.deploy_acm ? aws_acm_certificate_validation.env[0].certificate_arn : null

  alb_environment_tag = var.env == "prod" ? "production" : "development"
  alb_group_name      = var.alb_group_name
}