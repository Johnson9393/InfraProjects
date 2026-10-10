# IAM role assumed by the ESO controller through EKS Pod Identity.
resource "aws_iam_role" "eso_secrets_manager" {
  name = "${var.env}-eso-secrets-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Environment = var.env
    Application = "shopsphere"
    Component   = "external-secrets-operator"
  }
}

# Allows ESO to retrieve secret values and inspect secret metadata.
resource "aws_iam_role_policy" "eso_secrets_manager" {
  name = "${var.env}-eso-secrets-manager-read"
  role = aws_iam_role.eso_secrets_manager.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}/*"
      }
    ]
  })
}

# Associates the IAM role with the ESO controller's Kubernetes service account.
resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = local.eks_cluster_name
  namespace       = local.eso_namespace
  service_account = "eso-controller"
  role_arn        = aws_iam_role.eso_secrets_manager.arn
}
