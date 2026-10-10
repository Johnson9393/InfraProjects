
# Creates the ClusterSecretStore only when ESO integration is enabled.
resource "kubernetes_manifest" "cluster_secret_store" {
  count = var.enable_eso_secrets ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "${var.env}-aws-secrets-manager"
    }

    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
        }
      }
    }
  }
}

# Creates Kubernetes Secrets from AWS Secrets Manager values when enabled.
resource "kubernetes_manifest" "external_secrets" {
  for_each = var.enable_eso_secrets ? local.external_secret_targets : {}

  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"

    metadata = {
      name      = each.value.secret_name
      namespace = each.value.namespace
    }

    spec = {
      refreshInterval = "1h" #every 1hr it ESO will check for updates in the secret and update the k8s secret if there are any changes

      secretStoreRef = {
        name = "${var.env}-aws-secrets-manager"
        kind = "ClusterSecretStore"
      }

      target = {
        name           = each.value.secret_name
        creationPolicy = "Owner"
      }

      data = [
        for mapping in each.value.mappings : {
          secretKey = mapping.secretKey

          remoteRef = {
            key      = "${each.value.env_key}/${each.value.secret_name}"
            property = mapping.property
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_namespace_v1.shopsphere,
    kubernetes_manifest.cluster_secret_store
  ]
}
