#---------------------------------------
# Loki - Centralized logging for ShopSphere services
#---------------------------------------

resource "helm_release" "loki" {
  count = local.deploy_monitoring ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  version    = "2.10.2"
  timeout    = 600

  values = [
    yamlencode({
      loki = {
        enabled = true

        persistence = {
          enabled          = true
          storageClassName = "gp2"
          accessModes      = ["ReadWriteOnce"]
          size             = "20Gi"
        }

        config = {
          table_manager = {
            retention_deletes_enabled = true
            retention_period          = "168h"
          }
        }

        resources = {
          requests = {
            cpu    = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }

        service = {
          type = "ClusterIP"
          port = 3100
        }
      }

      promtail = {
        enabled = true

        config = {
          clients = [
            {
              url = "http://loki:3100/loki/api/v1/push"
            }
          ]
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      grafana = {
        enabled = false
      }

      prometheus = {
        enabled = false
      }

      fluent-bit = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.kube_prometheus_grafana_stack,
  ]
}