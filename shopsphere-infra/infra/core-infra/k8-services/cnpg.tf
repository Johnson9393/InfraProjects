# ============================================================================
# ShopSphere - CloudNativePG Operator
# ============================================================================

resource "kubernetes_namespace_v1" "cnpg" {
  metadata {
    name = local.cnpg_namespace

    labels = {
      "app.kubernetes.io/name"       = "cloudnative-pg"
      "app.kubernetes.io/part-of"    = "shopsphere"
      "app.kubernetes.io/managed-by" = "terraform"
      environment                   = var.env
    }
  }
}

resource "helm_release" "cnpg" {
  name       = "cnpg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = var.cnpg_chart_version
  namespace  = kubernetes_namespace_v1.cnpg.metadata[0].name

  values = [
    yamlencode({
      crds = {
        create = true
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
      }

      monitoring = {
        podMonitorEnabled = false
      }
    })
  ]

  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace_v1.cnpg
  ]
}
