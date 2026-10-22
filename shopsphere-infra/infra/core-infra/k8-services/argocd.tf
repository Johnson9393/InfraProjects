# Argo CD on this cluster (dev or prod). Host is argocd.<env>.infralabx.space
# so it matches ACM *.<env>.infralabx.space.
resource "kubernetes_namespace_v1" "argocd" {
  count = local.deploy_argocd ? 1 : 0

  metadata {
    name = local.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  count = local.deploy_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd[0].metadata[0].name

  set = [
    {
      name  = "server.service.type"
      value = "ClusterIP"
    },
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    }
  ]

  wait    = true
  timeout = 600

  depends_on = [time_sleep.wait_alb_webhook]
}

resource "kubernetes_ingress_v1" "argocd_ingress_tls" {
  count = local.deploy_argocd ? 1 : 0

  metadata {
    name      = "${var.env}-argocd-ingress"
    namespace = local.argocd_namespace
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/certificate-arn"          = local.acm_cert_arn
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/"
      "alb.ingress.kubernetes.io/healthcheck-protocol"     = "HTTP"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"
      "alb.ingress.kubernetes.io/tags"                     = "Environment=${local.alb_environment_tag},ManagedBy=Terraform,Name=${var.env}-${var.app_subdomain}-ingress"
      "alb.ingress.kubernetes.io/group.name"               = local.alb_group_name
    }
  }

  depends_on = [
    kubernetes_namespace_v1.argocd[0],
    helm_release.argocd[0],
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.env[0]
  ]

  wait_for_load_balancer = true

  timeouts {
    create = "10m"
    delete = "10m"
  }

  spec {
    ingress_class_name = "alb"

    tls {
      hosts = [
        "argocd.${var.env}.${var.domain_name}"
      ]
    }

    rule {
      host = "argocd.${var.env}.${var.domain_name}"

      http {
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
