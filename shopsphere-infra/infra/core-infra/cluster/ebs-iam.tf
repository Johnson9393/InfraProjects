# ============================================================================
# EKS OIDC Provider
# ============================================================================

# Creates the EKS cluster's OIDC Identity Provider in AWS IAM.
#
# This allows IAM to trust identities coming from Kubernetes
# ServiceAccounts through the EKS OIDC issuer.
#
# This is required for IRSA (IAM Roles for Service Accounts).

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {

  url = module.eks.cluster_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name      = "${var.eks_cluster_name}-eks-oidc"
    ManagedBy = "Terraform"
  }
}

# ============================================================================
# IAM Role for EBS CSI Driver - IRSA
# ============================================================================

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.eks_cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.eks_cluster_name}-ebs-csi-driver"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
