# Creates the ShopSphere namespace for each configured environment.
resource "kubernetes_namespace_v1" "shopsphere" {
  metadata {
    name = local.cluster_namespace

    labels = {
      environment                    = var.env
      app                            = "shopsphere"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}