resource "kubernetes_ingress_v1" "dojo_htpps_ingress" {
  metadata {
    name      = "${var.sub_domain}-ingress"
    namespace = kubernetes_namespace.dojo.metadata[0].name
    annotations = {
      # ALB configuration
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"

      # SSL/TLS configuration
      "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
      "alb.ingress.kubernetes.io/certificate-arn"     = aws_acm_certificate.dojo_cert.arn

      # Health check configuration
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/health"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"

      # Load balancer attributes
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"

      # Tags for the ALB
      "alb.ingress.kubernetes.io/tags" = "Environment=production,ManagedBy=Terraform,Name=${var.sub_domain}-ingress"

      # ALB group annotation
      # "alb.ingress.kubernetes.io/group.name" = var.alb_group_name
    }
  }

  wait_for_load_balancer = true

  depends_on = [
    kubernetes_namespace.dojo,
    aws_acm_certificate_validation.acm_validation
  ]

  spec {
    ingress_class_name = "alb"

    rule {
      host = "${var.sub_domain}.${var.domain_name}"

      http {
        # Route for backend API
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.backend_service.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }

        # Route for frontend (default)
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.frontend_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# try(expression, fallback)
# Get the expression using command  kubectl get ingress <ingress-name> -n <namespace> -o json
output "ingress_tls_hostname" {
  description = "The ALB hostname for the TLS ingress"
  value       = try(kubernetes_ingress_v1.dojo_htpps_ingress.status[0].load_balancer[0].ingress[0].hostname, "pending")
}
