
# Creates the ClusterSecretStore only when ESO integration is enabled.
# AWS Secrets Manager, this region.” Cluster-wide. No passwords in it — just where to talk. The ESO operator uses Pod Identity to actually call AWS
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

# It writes Kubernetes Secrets from AWS Secrets Manager values when enabled.
# one per app secret. “Take AWS key dev/product-db-credentials, fields username/password, write a Kubernetes Secret named product-db-credentials in shopsphere-dev.” Refresh every hour.
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
      # ESO re-reads AWS every hour. If the password rotated in Secrets Manager,
      # the Kubernetes Secret is updated. Reloader then restarts the app pods.
      refreshInterval = "1h"

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
    kubernetes_manifest.cluster_secret_store,
    aws_secretsmanager_secret_version.shopsphere,
    aws_secretsmanager_secret_version.rds_app,
  ]
}
