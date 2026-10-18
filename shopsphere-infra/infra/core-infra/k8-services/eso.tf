# Creates the namespace where the ESO controller will run.
resource "kubernetes_namespace_v1" "eso" {
  metadata {
    name = local.eso_namespace
  }
}

# Installs the External Secrets Operator and its required CRDs using Helm.
# knows how to turn an ExternalSecret into a Kubernetes Secret
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
}
