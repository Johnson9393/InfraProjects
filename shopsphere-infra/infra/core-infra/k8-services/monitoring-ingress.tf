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


# wait for alb controller to populate the alb DNS in ingress status
resource "time_sleep" "wait_for_monitoring_ingress" {
  count = local.deploy_monitoring ? 1 : 0

  depends_on = [
    kubernetes_ingress_v1.grafana_ingress[0],
    kubernetes_ingress_v1.prometheus_ingress[0],
  ]

  create_duration = "120s"
}


resource "aws_route53_record" "grafana" {
  count = local.deploy_monitoring ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana.${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name = kubernetes_ingress_v1.grafana_ingress[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = var.aws_alb_zoneid
    evaluate_target_health = true
  }

  depends_on = [kubernetes_ingress_v1.grafana_ingress, time_sleep.wait_for_monitoring_ingress]
}


resource "aws_route53_record" "prometheus" {
  count = local.deploy_monitoring ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "prometheus.${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name = kubernetes_ingress_v1.prometheus_ingress[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = var.aws_alb_zoneid
    evaluate_target_health = true
  }

  depends_on = [kubernetes_ingress_v1.prometheus_ingress, time_sleep.wait_for_monitoring_ingress]
}