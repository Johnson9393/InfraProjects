#------------------------------------------
# Prometheus and grafana Ingress Configuration
#-------------------------------------------

resource "kubernetes_ingress_v1" "prometheus_ingress" {
  count = local.deploy_monitoring ? 1 : 0

  metadata {
    name      = "${var.env}-prometheus-ingress"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/certificate-arn"          = local.acm_cert_arn
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/-/healthy"
      "alb.ingress.kubernetes.io/healthcheck-protocol"     = "HTTP"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"
      "alb.ingress.kubernetes.io/tags"                     = "Environment=${local.alb_environment_tag},ManagedBy=Terraform,Name=${var.app_subdomain}-ingress"
      "alb.ingress.kubernetes.io/group.name"               = local.alb_group_name
    }
  }

  wait_for_load_balancer = true

  timeouts {
    create = "10m"
    delete = "10m"
  }

  spec {
    ingress_class_name = "alb"

    tls {
      hosts = ["prometheus.${var.app_subdomain}.${var.domain_name}"]
    }

    rule {
      host = "prometheus.${var.app_subdomain}.${var.domain_name}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_grafana_stack[0],
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.env[0],
  ]
}

#----------------------------
### Grafana Ingress
#----------------------------

resource "kubernetes_ingress_v1" "grafana_ingress" {
  count = local.deploy_monitoring ? 1 : 0

  metadata {
    name      = "${var.env}-grafana-ingress"
    namespace = kubernetes_namespace_v1.monitoring[0].metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/certificate-arn"          = local.acm_cert_arn
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/api/health"
      "alb.ingress.kubernetes.io/healthcheck-protocol"     = "HTTP"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"
      "alb.ingress.kubernetes.io/tags"                     = "Environment=${local.alb_environment_tag},ManagedBy=Terraform,Name=${var.app_subdomain}-ingress"
      "alb.ingress.kubernetes.io/group.name"               = local.alb_group_name
    }
  }

  wait_for_load_balancer = true

  timeouts {
    create = "10m"
    delete = "10m"
  }

  spec {
    ingress_class_name = "alb"

    tls {
      hosts = ["grafana.${var.app_subdomain}.${var.domain_name}"]
    }

    rule {
      host = "grafana.${var.app_subdomain}.${var.domain_name}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_grafana_stack[0],
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.env[0],
  ]
}

