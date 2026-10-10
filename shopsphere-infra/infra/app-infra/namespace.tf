# Creates the ShopSphere namespace for each configured environment.
resource "kubernetes_namespace_v1" "shopsphere" {
  for_each = var.environments

  metadata {
    name = "shopsphere-${each.key}"

    labels = {
      environment                    = each.key
      app                            = "shopsphere"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}