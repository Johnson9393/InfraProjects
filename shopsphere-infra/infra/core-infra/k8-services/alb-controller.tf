
# ============================================================================
# AWS Load Balancer Controller - IAM Role, Policy, and Helm Release
# ============================================================================

# IAM role with IRSA trust policy
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller-${local.eks_cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks_oidc.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "${trimprefix(data.aws_iam_openid_connect_provider.eks_oidc.url, "https://")}:sub" = "system:serviceaccount:kube-system:${var.awsloadbalancercontroller_sa}"
            "${trimprefix(data.aws_iam_openid_connect_provider.eks_oidc.url, "https://")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "aws-load-balancer-controller-${local.eks_cluster_name}"
  }
}

# IAM policy using the official v2.11.0 policy JSON
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${local.eks_cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller v2.11.0"

  policy = file("${path.module}/alb-controller-iam-policy.json")

  tags = {
    Name = "${local.eks_cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  }
}

# Attach the IAM policy to the controller role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# Install AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.11.0"
  wait       = true
  timeout    = 600

  set = [
    {
      name  = "clusterName"
      value = local.eks_cluster_name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = data.aws_vpc.eks_vpc.id
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = var.awsloadbalancercontroller_sa
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.aws_load_balancer_controller.arn
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}


resource "time_sleep" "wait_alb_webhook" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "60s"
}
