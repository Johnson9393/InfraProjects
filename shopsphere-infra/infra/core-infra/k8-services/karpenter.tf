# HPA adds pods. Karpenter adds nodes when those pods have nowhere to run.
# Prod only. Dev keeps the fixed managed node group.
# The managed node group stays as the system pool (Karpenter, CoreDNS, ALB).

locals {
  karpenter_events = {
    health_event = {
      name        = "HealthEvent"
      description = "Karpenter interrupt - AWS health event"
      event_pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interrupt = {
      name        = "SpotInterrupt"
      description = "Karpenter interrupt - EC2 spot instance interruption warning"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    instance_rebalance = {
      name        = "InstanceRebalance"
      description = "Karpenter interrupt - EC2 instance rebalance recommendation"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    instance_state_change = {
      name        = "InstanceStateChange"
      description = "Karpenter interrupt - EC2 instance state-change notification"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
    capacity_reservation_interruption = {
      name        = "CRInterruption"
      description = "Karpenter interrupt - EC2 capacity reservation interruption"
      event_pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Capacity Reservation Instance Interruption Warning"]
      }
    }
  }
}

# Private app subnets only. RDS subnets stay out of this filter.
data "aws_subnets" "karpenter_private" {
  count = local.deploy_karpenter ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.env}-shopsphere-vpc-private-*"]
  }
}

resource "aws_ec2_tag" "karpenter_private_subnets" {
  for_each = local.deploy_karpenter ? toset(data.aws_subnets.karpenter_private[0].ids) : toset([])

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.eks_cluster_name
}

resource "aws_ec2_tag" "karpenter_cluster_sg" {
  count = local.deploy_karpenter ? 1 : 0

  resource_id = data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.eks_cluster_name
}

resource "aws_sqs_queue" "karpenter" {
  count = local.deploy_karpenter ? 1 : 0

  name                      = local.karpenter_queue_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

data "aws_iam_policy_document" "karpenter_queue" {
  count = local.deploy_karpenter ? 1 : 0

  statement {
    sid       = "SqsWrite"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.karpenter[0].arn]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "sqs.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "DenyHTTP"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.karpenter[0].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "karpenter" {
  count = local.deploy_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.karpenter[0].url
  policy    = data.aws_iam_policy_document.karpenter_queue[0].json
}

resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each = local.deploy_karpenter ? local.karpenter_events : {}

  name          = "${local.eks_cluster_name}-${each.value.name}"
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each = local.deploy_karpenter ? local.karpenter_events : {}

  rule      = aws_cloudwatch_event_rule.karpenter[each.key].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter[0].arn

  depends_on = [aws_sqs_queue_policy.karpenter]
}

resource "helm_release" "karpenter" {
  count = local.deploy_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version
  namespace  = local.karpenter_namespace

  values = [
    yamlencode({
      replicas = 2

      serviceAccount = {
        create = true
        name   = local.karpenter_sa
      }

      settings = {
        clusterName       = local.eks_cluster_name
        clusterEndpoint   = data.aws_eks_cluster.cluster.endpoint
        interruptionQueue = local.karpenter_queue_name
        eksControlPlane   = true
      }

      controller = {
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  wait    = true
  timeout = 600

  depends_on = [
    aws_iam_role_policy.karpenter_controller,
    aws_eks_pod_identity_association.karpenter,
    aws_eks_access_entry.karpenter_node,
    aws_sqs_queue_policy.karpenter,
    aws_ec2_tag.karpenter_private_subnets,
    aws_ec2_tag.karpenter_cluster_sg,
    time_sleep.wait_alb_webhook,
  ]
}

# How to launch a node: AMI, IAM role, private subnets, cluster security group.
resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  count = local.deploy_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"

    metadata = {
      name = "shopsphere-al2023"
    }

    spec = {
      role = try(aws_iam_role.karpenter_node[0].name, "")

      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.eks_cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.eks_cluster_name
          }
        }
      ]

      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "50Gi"
            volumeType          = "gp3"
            encrypted           = true
            deleteOnTermination = true
          }
        }
      ]

      tags = {
        Name        = "${local.eks_cluster_name}-karpenter"
        Environment = var.env
        Application = "shopsphere"
      }
    }
  })

  validate_schema   = false
  server_side_apply = true
  wait_for_rollout  = false

  depends_on = [helm_release.karpenter]
}

# When to launch a node: unschedulable pods, on-demand t/m medium-large, then consolidate.
resource "kubectl_manifest" "karpenter_nodepool" {
  count = local.deploy_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"

    metadata = {
      name = "shopsphere-apps"
    }

    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "shopsphere-al2023"
          }

          expireAfter = "720h"

          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t", "m"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["medium", "large"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            },
          ]
        }
      }

      limits = {
        cpu    = "16"
        memory = "32Gi"
      }

      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "5m"
      }
    }
  })

  validate_schema   = false
  server_side_apply = true
  wait_for_rollout  = false

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_ec2nodeclass,
  ]
}
