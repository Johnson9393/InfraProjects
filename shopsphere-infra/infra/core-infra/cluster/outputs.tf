output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_oidc_provider_arn" {
  description = "ARN of the EKS IAM OIDC provider"
  value       = module.eks.oidc_provider_arn
}