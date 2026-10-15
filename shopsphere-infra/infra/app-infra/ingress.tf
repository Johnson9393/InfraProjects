# ALB Ingress resources for ShopSphere services on the current cluster (var.env).
# Namespace is created separately by namespace.tf.
# Ingress is managed by Terraform; the AWS Load Balancer Controller
# reconciles the Kubernetes Ingress resource and provisions the ALB.

resource "kubernetes_ingress_v1" "service" {
  for_each = local.ingress_services

  metadata {
    name      = "${each.key}-ingress"
    namespace = each.value.namespace

    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"              = "443"
      "alb.ingress.kubernetes.io/certificate-arn"           = local.acm_cert_arn
      "alb.ingress.kubernetes.io/healthcheck-path"          = each.value.healthcheck_path
      "alb.ingress.kubernetes.io/healthcheck-protocol"      = "HTTP"
      "alb.ingress.kubernetes.io/load-balancer-attributes"  = "idle_timeout.timeout_seconds=60"
      "alb.ingress.kubernetes.io/ssl-policy"                = "ELBSecurityPolicy-TLS-1-2-2017-01"
      "alb.ingress.kubernetes.io/tags"                      = "Environment=${each.value.environment_label},ManagedBy=Terraform,Name=${var.app_subdomain}-ingress"
      "alb.ingress.kubernetes.io/group.name"                = local.alb_group_name
    }
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts = [each.value.host]
    }

    rule {
      host = each.value.host

      http {
        path {
          path      = each.value.path
          path_type = each.value.path_type

          backend {
            service {
              name = each.value.service_name

              port {
                number = each.value.service_port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.shopsphere,
    data.aws_acm_certificate.wildcard
  ]
}