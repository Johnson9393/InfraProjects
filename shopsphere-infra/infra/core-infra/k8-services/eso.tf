# Creates the namespace where the ESO controller will run.
resource "kubernetes_namespace_v1" "eso" {
  metadata {
    name = local.eso_namespace
  }
}

# Installs the External Secrets Operator and its required CRDs using Helm.
# The controller copies AWS Secrets Manager values into Kubernetes Secrets.
# Used on both dev and prod. Kubernetes Secrets are encrypted at rest with KMS.
resource "helm_release" "eso" {
  name       = "eso"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace_v1.eso.metadata[0].name

  # Enables the CRDs used by ClusterSecretStore and ExternalSecret.
  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "eso-controller"
    }
  ]

  # Waits for the Helm installation to finish.
  timeout = 600

  depends_on = [time_sleep.wait_alb_webhook]
}
