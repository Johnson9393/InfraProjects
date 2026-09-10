resource "kubernetes_ingress_v1" "argo_https_ingress" {
  metadata {
    name      = "${var.sub_domain}-ingress"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    annotations = {
      # ALB configuration
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"

      # SSL/TLS configuration
      "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
      "alb.ingress.kubernetes.io/certificate-arn"     = aws_acm_certificate.argo_cert.arn

      # Health check configuration
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/health"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"

      # Load balancer attributes
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"

      # Tags for the ALB
      "alb.ingress.kubernetes.io/tags" = "Environment=production,ManagedBy=Terraform,Name=${var.sub_domain}-ingress"

      # ALB group annotation
      "alb.ingress.kubernetes.io/group.name" = var.alb_group_name
    }
  }

  wait_for_load_balancer = true

  depends_on = [
    kubernetes_namespace_v1.argocd,
    aws_acm_certificate_validation.acm_validation,
    helm_release.argocd
  ]

  spec {
    ingress_class_name = "alb"

    rule {
      host = "${var.sub_domain}.${var.domain_name}"

      http {

        # Route for argocd server (default)
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
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
  description = "The ALB hostname of argo for the TLS ingress"
  value       = try(kubernetes_ingress_v1.argo_https_ingress.status[0].load_balancer[0].ingress[0].hostname, "pending")
}
