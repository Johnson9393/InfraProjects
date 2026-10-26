
# -----------------------------------------------------------------------------
# CloudNativePG PostgreSQL clusters — Dev only
#
# Prerequisites:
#   - CNPG operator installed by core-infra/k8-services/cnpg.tf
#   - shopsphere namespace exists
#   - ESO has synchronised the required database credentials into Kubernetes
#
# Production PostgreSQL will be configured separately using RDS.
# -----------------------------------------------------------------------------

# Wait for External Secrets Operator to sync AWS Secrets Manager values
# into Kubernetes Secrets before CNPG, Redis, and RabbitMQ read them.
resource "time_sleep" "wait_for_cnpg_credentials" {
  count = var.enable_eso_secrets ? 1 : 0

  create_duration = "180s"

  depends_on = [
    kubernetes_manifest.external_secrets,
    aws_secretsmanager_secret_version.shopsphere,
  ]
}

# Read the ESO-managed credentials required by each PostgreSQL cluster.
data "kubernetes_secret_v1" "cnpg_credentials" {
  for_each = local.cnpg_clusters_effective

  metadata {
    name      = each.value.secret_name
    namespace = each.value.namespace
  }

  depends_on = [
    kubernetes_namespace_v1.shopsphere,
    kubernetes_manifest.external_secrets,
    time_sleep.wait_for_cnpg_credentials,
  ]
}

# Create the PostgreSQL clusters through the CloudNativePG Kubernetes CRD.
resource "kubernetes_manifest" "cnpg_cluster" {
  for_each = local.cnpg_clusters_effective

  computed_fields = ["spec.postgresql.parameters"]

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"

    metadata = {
      name      = each.value.cluster_name
      namespace = each.value.namespace

      labels = {
        app                            = each.value.cluster_name
        environment                    = each.value.environment
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = "shopsphere"
      }
    }

    spec = {
      # Number of PostgreSQL instances in each cluster.
      instances = var.cnpg_instances

      # PostgreSQL container image.
      imageName = var.cnpg_image

      # Initialise the database and its owner using ESO-managed credentials.
      bootstrap = {
        initdb = {
          database = each.value.database
          owner    = each.value.owner

          secret = {
            name = each.value.secret_name
          }

          postInitApplicationSQL = [
            "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
          ]
        }
      }

      postgresql = {
        parameters = {
          max_connections      = var.cnpg_postgresql.max_connections
          shared_buffers       = var.cnpg_postgresql.shared_buffers
          effective_cache_size = var.cnpg_postgresql.effective_cache_size
          work_mem             = var.cnpg_postgresql.work_mem
          maintenance_work_mem = var.cnpg_postgresql.maintenance_work_mem

          log_statement      = "ddl"
          log_connections    = "on"
          log_disconnections = "on"
        }
      }

      # Persistent storage for each PostgreSQL instance.
      storage = {
        size         = var.cnpg_storage
        storageClass = var.cnpg_storage_class
      }

      resources = {
        requests = {
          cpu    = var.cnpg_resources.requests.cpu
          memory = var.cnpg_resources.requests.memory
        }

        limits = {
          cpu    = var.cnpg_resources.limits.cpu
          memory = var.cnpg_resources.limits.memory
        }
      }

      monitoring = {
        enablePodMonitor = var.cnpg_enable_pod_monitor
      }

      # Automatically apply supported primary updates.
      primaryUpdateStrategy = "unsupervised"

      # Failover and switchover behaviour.
      failoverDelay   = 0
      switchoverDelay = 10
    }
  }

  depends_on = [
    data.kubernetes_secret_v1.cnpg_credentials
  ]
}


# ------------------------------------------------------------------------------
# Redis Configuration — Dev only
# Prod uses ElastiCache in elasticache-redis.tf. local.redis_incluster_enabled
# is false there, so this Deployment and Service are skipped.
# ------------------------------------------------------------------------------

data "kubernetes_secret_v1" "redis_credentials" {
  count = local.redis_incluster_enabled ? 1 : 0
  metadata {
    name      = "redis-credentials"
    namespace = local.cluster_namespace
  }

  depends_on = [
    kubernetes_namespace_v1.shopsphere,
    kubernetes_manifest.external_secrets,
    time_sleep.wait_for_cnpg_credentials
  ]
}

resource "kubernetes_deployment_v1" "redis" {
  count = local.redis_incluster_enabled ? 1 : 0
  metadata {
    name      = "redis"
    namespace = local.cluster_namespace

    labels = {
      app                            = "redis"
      environment                    = var.env
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "shopsphere"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name              = "redis"
          image             = var.redis_image
          image_pull_policy = "IfNotPresent"

          command = [
            "sh",
            "-c",
            "exec redis-server --appendonly yes --maxmemory ${var.redis_max_memory} --maxmemory-policy allkeys-lru --requirepass \"$REDIS_PASSWORD\""
          ]

          env {
            name = "REDIS_PASSWORD"

            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.redis_credentials[0].metadata[0].name
                key  = "password"
              }
            }
          }

          port {
            container_port = 6379
          }

          readiness_probe {
            exec {
              command = [
                "sh",
                "-c",
                "redis-cli -a \"$REDIS_PASSWORD\" ping"
              ]
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = var.redis_resources.requests.cpu
              memory = var.redis_resources.requests.memory
            }

            limits = {
              cpu    = var.redis_resources.limits.cpu
              memory = var.redis_resources.limits.memory
            }
          }
        }
      }
    }
  }

  wait_for_rollout = false

  depends_on = [
    data.kubernetes_secret_v1.redis_credentials
  ]
}

resource "kubernetes_service_v1" "redis" {
  count = local.redis_incluster_enabled ? 1 : 0
  metadata {
    name      = "redis"
    namespace = local.cluster_namespace

    labels = {
      app = "redis"
    }
  }

  spec {
    selector = {
      app = "redis"
    }

    port {
      port        = 6379
      target_port = 6379
    }

    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_deployment_v1.redis
  ]
}


# ------------------------------------------------------------------------------
# RabbitMQ Configuration
# Deploys RabbitMQ as a StatefulSet with persistent storage and an internal Service.
# ------------------------------------------------------------------------------

data "kubernetes_secret_v1" "rabbitmq_credentials" {
  count = var.rabbitmq_enabled ? 1 : 0

  metadata {
    name      = "rabbitmq-credentials"
    namespace = local.cluster_namespace
  }

  depends_on = [
    kubernetes_namespace_v1.shopsphere,
    kubernetes_manifest.external_secrets,
    time_sleep.wait_for_cnpg_credentials
  ]
}

resource "kubernetes_manifest" "rabbitmq" {
  count = var.rabbitmq_enabled ? 1 : 0

  manifest = {
    apiVersion = "apps/v1"
    kind       = "StatefulSet"

    metadata = {
      name      = "rabbitmq"
      namespace = local.cluster_namespace

      labels = {
        app                            = "rabbitmq"
        environment                    = var.env
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = "shopsphere"
      }
    }

    spec = {
      serviceName = "rabbitmq"
      replicas    = 1

      selector = {
        matchLabels = {
          app = "rabbitmq"
        }
      }

      template = {
        metadata = {
          labels = {
            app = "rabbitmq"
          }
        }

        spec = {
          containers = [
            {
              name            = "rabbitmq"
              image           = var.rabbitmq_image
              imagePullPolicy = "IfNotPresent"

              ports = [
                { containerPort = 5672, name = "amqp" },
                { containerPort = 15672, name = "management" }
              ]

              env = [
                {
                  name = "RABBITMQ_DEFAULT_USER"
                  valueFrom = {
                    secretKeyRef = {
                      name = data.kubernetes_secret_v1.rabbitmq_credentials[0].metadata[0].name
                      key  = "username"
                    }
                  }
                },
                {
                  name = "RABBITMQ_DEFAULT_PASS"
                  valueFrom = {
                    secretKeyRef = {
                      name = data.kubernetes_secret_v1.rabbitmq_credentials[0].metadata[0].name
                      key  = "password"
                    }
                  }
                }
              ]

              readinessProbe = {
                exec = {
                  command = ["rabbitmq-diagnostics", "check_running"]
                }
                initialDelaySeconds = 30
                periodSeconds       = 15
                timeoutSeconds      = 15
                failureThreshold    = 6
              }

              livenessProbe = {
                exec = {
                  command = ["rabbitmq-diagnostics", "ping"]
                }
                initialDelaySeconds = 90
                periodSeconds       = 30
                timeoutSeconds      = 15
                failureThreshold    = 3
              }

              volumeMounts = [
                {
                  name      = "data"
                  mountPath = "/var/lib/rabbitmq"
                }
              ]

              resources = {
                requests = {
                  cpu    = var.rabbitmq_resources.requests.cpu
                  memory = var.rabbitmq_resources.requests.memory
                }
                limits = {
                  cpu    = var.rabbitmq_resources.limits.cpu
                  memory = var.rabbitmq_resources.limits.memory
                }
              }
            }
          ]
        }
      }

      volumeClaimTemplates = [
        {
          metadata = {
            name = "data"
          }

          spec = {
            accessModes      = ["ReadWriteOnce"]
            storageClassName = var.storage_class

            resources = {
              requests = {
                storage = var.rabbitmq_storage
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [
    data.kubernetes_secret_v1.rabbitmq_credentials
  ]
}

resource "kubernetes_service_v1" "rabbitmq" {
  count = var.rabbitmq_enabled ? 1 : 0

  metadata {
    name      = "rabbitmq"
    namespace = local.cluster_namespace

    labels = {
      app                            = "rabbitmq"
      environment                    = var.env
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "shopsphere"
    }
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }

    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_manifest.rabbitmq
  ]
}
