# ============================================================================
# KMS key for EKS Secrets encryption
# ============================================================================

resource "aws_kms_key" "eks_secrets" {
  description = "KMS key for encrypting Kubernetes Secrets in the ShopSphere EKS cluster"

  enable_key_rotation = true

  tags = {
    Name = "${var.eks_cluster_name}-secrets"
  }
}

# ============================================================================
# KMS alias
# ============================================================================

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.eks_cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}