
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
      # One primary and two replicas. After one zone is lost, a primary and a replica remain.
      instances = var.cnpg_instances

      # PostgreSQL container image.
      imageName = var.cnpg_image

      # Prefer a different zone for each pod, and still allow a pod to share a zone
      # so a replacement can start after one zone is lost.
      affinity = {
        enablePodAntiAffinity = true
        topologyKey           = "topology.kubernetes.io/zone"
        podAntiAffinityType   = "preferred"
      }

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
        # A commit succeeds only after one replica has the change.
        # Wait for one replica when one is reachable. If a zone is gone and
        # only the primary is left, the commit still succeeds.
        synchronous = {
          method         = "any"
          number         = 1
          dataDurability = "preferred"
        }

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
# Redis — Dev only. Prod uses ElastiCache.
#
# Three data pods. Sentinel runs separately and keeps no disk, so if a zone
# is lost those pods start again in the zone that is still up and promote the
# Redis copy there. The cart service still uses redis:6379. redis-endpoint
# points that Service at the current primary.
# ------------------------------------------------------------------------------

locals {
  redis_start_script = <<-SCRIPT
    #!/bin/sh
    set -u

    NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    ORDINAL=$(printf '%s' "$HOSTNAME" | awk -F- '{print $NF}')
    DOMAIN="redis-headless.$${NS}.svc.cluster.local"
    SENTINEL_DOMAIN="redis-sentinel.$${NS}.svc.cluster.local"
    MY_FQDN="$${HOSTNAME}.$${DOMAIN}"
    MASTER_NAME=shopsphere
    DATA=/data

    mkdir -p "$DATA"

    find_master() {
      i=0
      while [ "$i" -lt "$SENTINEL_REPLICAS" ]; do
        addr=$(redis-cli -t 1 -h "redis-sentinel-$${i}.$${SENTINEL_DOMAIN}" -p 26379 --raw SENTINEL get-master-addr-by-name "$MASTER_NAME" 2>/dev/null | awk 'NR==1 {print; exit}')
        if [ -n "$addr" ]; then
          printf '%s' "$addr"
          return 0
        fi
        i=$((i + 1))
      done
      return 1
    }

    REPLICAOF_LINE=""
    CURRENT=$(find_master || true)
    if [ -n "$CURRENT" ] && [ "$CURRENT" != "$MY_FQDN" ]; then
      REPLICAOF_LINE="replicaof $CURRENT 6379"
    elif [ -z "$CURRENT" ] && [ "$ORDINAL" != "0" ]; then
      REPLICAOF_LINE="replicaof redis-0.$${DOMAIN} 6379"
    fi

    {
      echo "bind 0.0.0.0"
      echo "port 6379"
      echo "protected-mode yes"
      echo "requirepass $REDIS_PASSWORD"
      echo "masterauth $REDIS_PASSWORD"
      echo "appendonly yes"
      echo "dir $DATA"
      echo "maxmemory $REDIS_MAX_MEMORY"
      echo "maxmemory-policy allkeys-lru"
      echo "replica-announce-ip $MY_FQDN"
      echo "replica-announce-port 6379"
      if [ -n "$REPLICAOF_LINE" ]; then
        echo "$REPLICAOF_LINE"
      fi
    } > "$DATA/redis.conf"

    exec redis-server "$DATA/redis.conf"
  SCRIPT

  redis_sentinel_script = <<-SCRIPT
    #!/bin/sh
    set -u

    NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    DOMAIN="redis-headless.$${NS}.svc.cluster.local"
    MASTER_NAME=shopsphere

    {
      echo "port 26379"
      echo "bind 0.0.0.0"
      echo "sentinel resolve-hostnames yes"
      echo "sentinel announce-hostnames yes"
      echo "sentinel monitor $MASTER_NAME redis-0.$${DOMAIN} 6379 2"
      echo "sentinel down-after-milliseconds $MASTER_NAME 5000"
      echo "sentinel failover-timeout $MASTER_NAME 60000"
      echo "sentinel parallel-syncs $MASTER_NAME 1"
      echo "sentinel auth-pass $MASTER_NAME $REDIS_PASSWORD"
      echo "sentinel announce-ip $POD_IP"
      echo "sentinel announce-port 26379"
    } > /tmp/sentinel.conf

    exec redis-sentinel /tmp/sentinel.conf
  SCRIPT

  redis_endpoint_script = <<-SCRIPT
    #!/bin/sh
    set -u
    apk add --no-cache redis curl >/dev/null

    NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    TOKEN_FILE=/var/run/secrets/kubernetes.io/serviceaccount/token
    CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    DOMAIN="redis-sentinel.$${NS}.svc.cluster.local"
    MASTER_NAME=shopsphere

    while true; do
      i=0
      ADDR=""
      while [ "$i" -lt "$SENTINEL_REPLICAS" ]; do
        ADDR=$(redis-cli -t 1 -h "redis-sentinel-$${i}.$${DOMAIN}" -p 26379 --raw SENTINEL get-master-addr-by-name "$MASTER_NAME" 2>/dev/null | awk 'NR==1 {print; exit}')
        if [ -n "$ADDR" ]; then
          break
        fi
        i=$((i + 1))
      done

      if [ -n "$ADDR" ]; then
        IP=$(getent hosts "$ADDR" | awk '{print $1; exit}')
        if [ -n "$IP" ]; then
          BODY=$(printf '{"apiVersion":"v1","kind":"Endpoints","metadata":{"name":"redis","namespace":"%s"},"subsets":[{"addresses":[{"ip":"%s"}],"ports":[{"name":"redis","port":6379,"protocol":"TCP"}]}]}' "$NS" "$IP")
          CODE=$(curl -sS -o /tmp/ep-out -w '%%{http_code}' --cacert "$CA" -H "Authorization: Bearer $(cat "$TOKEN_FILE")" -H "Content-Type: application/json" -X PUT "https://kubernetes.default.svc/api/v1/namespaces/$${NS}/endpoints/redis" -d "$BODY" || true)
          if [ "$CODE" = "404" ]; then
            curl -sS -o /dev/null --cacert "$CA" -H "Authorization: Bearer $(cat "$TOKEN_FILE")" -H "Content-Type: application/json" -X POST "https://kubernetes.default.svc/api/v1/namespaces/$${NS}/endpoints" -d "$BODY" || true
          fi
        fi
      fi
      sleep 5
    done
  SCRIPT
}

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

resource "kubernetes_manifest" "redis_scripts" {
  count = local.redis_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"

    metadata = {
      name      = "redis-scripts"
      namespace = local.cluster_namespace
    }

    data = {
      "start.sh"    = local.redis_start_script
      "sentinel.sh" = local.redis_sentinel_script
      "follow.sh"   = local.redis_endpoint_script
    }
  }
}

resource "kubernetes_manifest" "redis_endpoint_rbac" {
  for_each = local.redis_incluster_enabled ? toset(["sa", "role", "binding"]) : toset([])

  manifest = {
    sa = {
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name      = "redis-endpoint"
        namespace = local.cluster_namespace
      }
    }
    role = {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name      = "redis-endpoint"
        namespace = local.cluster_namespace
      }
      rules = [
        {
          apiGroups = [""]
          resources = ["endpoints"]
          verbs     = ["get", "create", "update", "patch"]
        }
      ]
    }
    binding = {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name      = "redis-endpoint"
        namespace = local.cluster_namespace
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Role"
        name     = "redis-endpoint"
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = "redis-endpoint"
          namespace = local.cluster_namespace
        }
      ]
    }
  }[each.key]
}

resource "kubernetes_manifest" "redis" {
  count = local.redis_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "apps/v1"
    kind       = "StatefulSet"

    metadata = {
      name      = "redis"
      namespace = local.cluster_namespace
      labels = {
        app                            = "redis"
        environment                    = var.env
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = "shopsphere"
      }
    }

    spec = {
      serviceName         = "redis-headless"
      replicas            = var.redis_replicas
      podManagementPolicy = "OrderedReady"

      selector = {
        matchLabels = {
          app = "redis"
        }
      }

      template = {
        metadata = {
          labels = {
            app = "redis"
          }
        }

        spec = {
          securityContext = {
            fsGroup = 999
          }

          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    topologyKey = "topology.kubernetes.io/zone"
                    labelSelector = {
                      matchLabels = {
                        app = "redis"
                      }
                    }
                  }
                }
              ]
            }
          }

          containers = [
            {
              name            = "redis"
              image           = var.redis_image
              imagePullPolicy = "IfNotPresent"
              command         = ["sh", "/scripts/start.sh"]

              env = [
                {
                  name = "REDIS_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = data.kubernetes_secret_v1.redis_credentials[0].metadata[0].name
                      key  = "password"
                    }
                  }
                },
                {
                  name  = "REDIS_MAX_MEMORY"
                  value = var.redis_max_memory
                },
                {
                  name  = "SENTINEL_REPLICAS"
                  value = tostring(var.redis_sentinel_replicas)
                }
              ]

              ports = [
                { containerPort = 6379, name = "redis" }
              ]

              readinessProbe = {
                exec = {
                  command = ["sh", "-c", "redis-cli -a \"$REDIS_PASSWORD\" --no-auth-warning ping | grep -q PONG"]
                }
                initialDelaySeconds = 10
                periodSeconds       = 5
                timeoutSeconds      = 3
                failureThreshold    = 12
              }

              livenessProbe = {
                exec = {
                  command = ["sh", "-c", "redis-cli -a \"$REDIS_PASSWORD\" --no-auth-warning ping | grep -q PONG"]
                }
                initialDelaySeconds = 20
                periodSeconds       = 10
                timeoutSeconds      = 3
                failureThreshold    = 6
              }

              volumeMounts = [
                { name = "data", mountPath = "/data" },
                { name = "scripts", mountPath = "/scripts" }
              ]

              resources = {
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
          ]

          volumes = [
            {
              name = "scripts"
              configMap = {
                name = "redis-scripts"
              }
            }
          ]
        }
      }

      volumeClaimTemplates = [
        {
          metadata = { name = "data" }
          spec = {
            accessModes      = ["ReadWriteOnce"]
            storageClassName = var.storage_class
            resources = {
              requests = {
                storage = var.redis_storage
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [
    data.kubernetes_secret_v1.redis_credentials,
    kubernetes_manifest.redis_scripts,
  ]
}

resource "kubernetes_manifest" "redis_headless" {
  count = local.redis_incluster_enabled ? 1 : 0

  computed_fields = ["spec.clusterIP", "spec.clusterIPs"]

  manifest = {
    apiVersion = "v1"
    kind       = "Service"

    metadata = {
      name      = "redis-headless"
      namespace = local.cluster_namespace
      labels    = { app = "redis" }
    }

    spec = {
      clusterIP                = "None"
      publishNotReadyAddresses = true
      selector                 = { app = "redis" }
      ports = [
        { name = "redis", port = 6379, targetPort = 6379 }
      ]
    }
  }
}

resource "kubernetes_manifest" "redis_sentinel_service" {
  count = local.redis_incluster_enabled ? 1 : 0

  computed_fields = ["spec.clusterIP", "spec.clusterIPs"]

  manifest = {
    apiVersion = "v1"
    kind       = "Service"

    metadata = {
      name      = "redis-sentinel"
      namespace = local.cluster_namespace
      labels    = { app = "redis-sentinel" }
    }

    spec = {
      clusterIP                = "None"
      publishNotReadyAddresses = true
      selector                 = { app = "redis-sentinel" }
      ports = [
        { name = "sentinel", port = 26379, targetPort = 26379 }
      ]
    }
  }
}

resource "kubernetes_manifest" "redis_sentinel" {
  count = local.redis_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "apps/v1"
    kind       = "StatefulSet"

    metadata = {
      name      = "redis-sentinel"
      namespace = local.cluster_namespace
      labels = {
        app                            = "redis-sentinel"
        environment                    = var.env
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = "shopsphere"
      }
    }

    spec = {
      serviceName         = "redis-sentinel"
      replicas            = var.redis_sentinel_replicas
      podManagementPolicy = "Parallel"

      selector = {
        matchLabels = { app = "redis-sentinel" }
      }

      template = {
        metadata = {
          labels = { app = "redis-sentinel" }
        }

        spec = {
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    topologyKey = "topology.kubernetes.io/zone"
                    labelSelector = {
                      matchLabels = { app = "redis-sentinel" }
                    }
                  }
                }
              ]
            }
          }

          containers = [
            {
              name            = "sentinel"
              image           = var.redis_image
              imagePullPolicy = "IfNotPresent"
              command         = ["sh", "/scripts/sentinel.sh"]

              env = [
                {
                  name = "REDIS_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = data.kubernetes_secret_v1.redis_credentials[0].metadata[0].name
                      key  = "password"
                    }
                  }
                },
                {
                  name = "POD_IP"
                  valueFrom = {
                    fieldRef = { fieldPath = "status.podIP" }
                  }
                }
              ]

              ports = [
                { containerPort = 26379, name = "sentinel" }
              ]

              readinessProbe = {
                exec = {
                  command = ["redis-cli", "-p", "26379", "ping"]
                }
                initialDelaySeconds = 5
                periodSeconds       = 5
                timeoutSeconds      = 3
                failureThreshold    = 6
              }

              volumeMounts = [
                { name = "scripts", mountPath = "/scripts" }
              ]

              resources = {
                requests = { cpu = "20m", memory = "32Mi" }
                limits   = { cpu = "100m", memory = "64Mi" }
              }
            }
          ]

          volumes = [
            {
              name      = "scripts"
              configMap = { name = "redis-scripts" }
            }
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.redis_scripts,
    kubernetes_manifest.redis_sentinel_service,
    data.kubernetes_secret_v1.redis_credentials,
  ]
}

# Cart service keeps using redis:6379. Endpoints are written by redis-endpoint.
resource "kubernetes_manifest" "redis_service" {
  count = local.redis_incluster_enabled ? 1 : 0

  computed_fields = ["spec.clusterIP", "spec.clusterIPs"]

  manifest = {
    apiVersion = "v1"
    kind       = "Service"

    metadata = {
      name      = "redis"
      namespace = local.cluster_namespace
      labels    = { app = "redis" }
    }

    spec = {
      ports = [
        { name = "redis", port = 6379, targetPort = 6379 }
      ]
    }
  }
}

resource "kubernetes_manifest" "redis_endpoint" {
  count = local.redis_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"

    metadata = {
      name      = "redis-endpoint"
      namespace = local.cluster_namespace
      labels = {
        app                            = "redis-endpoint"
        environment                    = var.env
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = "shopsphere"
      }
    }

    spec = {
      replicas = 2
      selector = {
        matchLabels = { app = "redis-endpoint" }
      }
      template = {
        metadata = {
          labels = { app = "redis-endpoint" }
        }
        spec = {
          serviceAccountName = "redis-endpoint"
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    topologyKey = "topology.kubernetes.io/zone"
                    labelSelector = {
                      matchLabels = { app = "redis-endpoint" }
                    }
                  }
                }
              ]
            }
          }
          containers = [
            {
              name            = "follow"
              image           = "alpine:3.20"
              imagePullPolicy = "IfNotPresent"
              command         = ["sh", "/scripts/follow.sh"]
              env = [
                {
                  name = "REDIS_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = data.kubernetes_secret_v1.redis_credentials[0].metadata[0].name
                      key  = "password"
                    }
                  }
                },
                {
                  name  = "SENTINEL_REPLICAS"
                  value = tostring(var.redis_sentinel_replicas)
                }
              ]
              volumeMounts = [
                { name = "scripts", mountPath = "/scripts" }
              ]
              resources = {
                requests = { cpu = "20m", memory = "32Mi" }
                limits   = { cpu = "100m", memory = "64Mi" }
              }
            }
          ]
          volumes = [
            {
              name      = "scripts"
              configMap = { name = "redis-scripts" }
            }
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.redis,
    kubernetes_manifest.redis_sentinel,
    kubernetes_manifest.redis_service,
    kubernetes_manifest.redis_endpoint_rbac,
  ]
}

resource "kubernetes_manifest" "redis_pdb" {
  count = local.redis_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "policy/v1"
    kind       = "PodDisruptionBudget"
    metadata = {
      name      = "redis"
      namespace = local.cluster_namespace
    }
    spec = {
      minAvailable = 2
      selector = {
        matchLabels = { app = "redis" }
      }
    }
  }
}


# ------------------------------------------------------------------------------
# RabbitMQ — Dev only. Prod uses Amazon MQ.
#
# Two brokers, one in each zone when the scheduler can. Every queue is
# mirrored, so the broker left after a zone is lost still has the messages.
# Services still use rabbitmq:5672.
# ------------------------------------------------------------------------------

data "kubernetes_secret_v1" "rabbitmq_credentials" {
  count = local.rabbitmq_incluster_enabled ? 1 : 0

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

resource "kubernetes_manifest" "rabbitmq_config" {
  count = local.rabbitmq_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"

    metadata = {
      name      = "rabbitmq-config"
      namespace = local.cluster_namespace
    }

    data = {
      "enabled_plugins" = "[rabbitmq_management,rabbitmq_peer_discovery_k8s].\n"
      "rabbitmq.conf" = join("\n", [
        "cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s",
        "cluster_formation.k8s.host = kubernetes.default.svc.cluster.local",
        "cluster_formation.k8s.address_type = hostname",
        "cluster_formation.k8s.service_name = rabbitmq-headless",
        "cluster_formation.k8s.hostname_suffix = .rabbitmq-headless.${local.cluster_namespace}.svc.cluster.local",
        "cluster_formation.node_cleanup.interval = 30",
        "cluster_formation.node_cleanup.only_log_warning = true",
        "cluster_partition_handling = autoheal",
        "management.load_definitions = /etc/rabbitmq/definitions.json",
      ])
      "definitions.json" = jsonencode({
        vhosts = [{ name = "/" }]
        policies = [
          {
            vhost      = "/"
            name       = "mirror-all"
            pattern    = ".*"
            "apply-to" = "queues"
            definition = { "ha-mode" = "all", "ha-sync-mode" = "automatic" }
            priority   = 0
          }
        ]
      })
    }
  }
}

resource "kubernetes_manifest" "rabbitmq_rbac" {
  for_each = local.rabbitmq_incluster_enabled ? toset(["sa", "role", "binding"]) : toset([])

  manifest = {
    sa = {
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name      = "rabbitmq"
        namespace = local.cluster_namespace
      }
    }
    role = {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name      = "rabbitmq"
        namespace = local.cluster_namespace
      }
      rules = [
        {
          apiGroups = [""]
          resources = ["endpoints"]
          verbs     = ["get", "list", "watch"]
        },
        {
          apiGroups = [""]
          resources = ["events"]
          verbs     = ["create"]
        }
      ]
    }
    binding = {
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name      = "rabbitmq"
        namespace = local.cluster_namespace
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Role"
        name     = "rabbitmq"
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = "rabbitmq"
          namespace = local.cluster_namespace
        }
      ]
    }
  }[each.key]
}

resource "kubernetes_manifest" "rabbitmq_headless" {
  count = local.rabbitmq_incluster_enabled ? 1 : 0

  computed_fields = ["spec.clusterIP", "spec.clusterIPs"]

  manifest = {
    apiVersion = "v1"
    kind       = "Service"

    metadata = {
      name      = "rabbitmq-headless"
      namespace = local.cluster_namespace
      labels    = { app = "rabbitmq" }
    }

    spec = {
      clusterIP                = "None"
      publishNotReadyAddresses = true
      selector                 = { app = "rabbitmq" }
      ports = [
        { name = "amqp", port = 5672, targetPort = 5672 },
        { name = "management", port = 15672, targetPort = 15672 },
        { name = "epmd", port = 4369, targetPort = 4369 },
        { name = "clustering", port = 25672, targetPort = 25672 }
      ]
    }
  }
}

resource "kubernetes_manifest" "rabbitmq" {
  count = local.rabbitmq_incluster_enabled ? 1 : 0

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
      serviceName         = "rabbitmq-headless"
      replicas            = var.rabbitmq_replicas
      podManagementPolicy = "Parallel"

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
          serviceAccountName = "rabbitmq"

          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    topologyKey = "topology.kubernetes.io/zone"
                    labelSelector = {
                      matchLabels = {
                        app = "rabbitmq"
                      }
                    }
                  }
                }
              ]
            }
          }

          containers = [
            {
              name            = "rabbitmq"
              image           = var.rabbitmq_image
              imagePullPolicy = "IfNotPresent"

              ports = [
                { containerPort = 5672, name = "amqp" },
                { containerPort = 15672, name = "management" },
                { containerPort = 4369, name = "epmd" },
                { containerPort = 25672, name = "clustering" }
              ]

              env = [
                {
                  name  = "RABBITMQ_USE_LONGNAME"
                  value = "true"
                },
                {
                  name = "MY_POD_NAME"
                  valueFrom = {
                    fieldRef = { fieldPath = "metadata.name" }
                  }
                },
                {
                  name = "MY_POD_NAMESPACE"
                  valueFrom = {
                    fieldRef = { fieldPath = "metadata.namespace" }
                  }
                },
                {
                  name  = "K8S_SERVICE_NAME"
                  value = "rabbitmq-headless"
                },
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
                },
                {
                  name = "RABBITMQ_ERLANG_COOKIE"
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
                  command = ["rabbitmq-diagnostics", "-q", "check_port_connectivity"]
                }
                initialDelaySeconds = 30
                periodSeconds       = 15
                timeoutSeconds      = 15
                failureThreshold    = 8
              }

              livenessProbe = {
                exec = {
                  command = ["rabbitmq-diagnostics", "-q", "ping"]
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
                },
                {
                  name      = "config"
                  mountPath = "/etc/rabbitmq/rabbitmq.conf"
                  subPath   = "rabbitmq.conf"
                },
                {
                  name      = "config"
                  mountPath = "/etc/rabbitmq/enabled_plugins"
                  subPath   = "enabled_plugins"
                },
                {
                  name      = "config"
                  mountPath = "/etc/rabbitmq/definitions.json"
                  subPath   = "definitions.json"
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

          volumes = [
            {
              name = "config"
              configMap = {
                name = "rabbitmq-config"
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
    data.kubernetes_secret_v1.rabbitmq_credentials,
    kubernetes_manifest.rabbitmq_config,
    kubernetes_manifest.rabbitmq_rbac,
    kubernetes_manifest.rabbitmq_headless,
  ]
}

resource "kubernetes_manifest" "rabbitmq_pdb" {
  count = local.rabbitmq_incluster_enabled ? 1 : 0

  manifest = {
    apiVersion = "policy/v1"
    kind       = "PodDisruptionBudget"
    metadata = {
      name      = "rabbitmq"
      namespace = local.cluster_namespace
    }
    spec = {
      minAvailable = 1
      selector = {
        matchLabels = { app = "rabbitmq" }
      }
    }
  }
}

resource "kubernetes_service_v1" "rabbitmq" {
  count = local.rabbitmq_incluster_enabled ? 1 : 0

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
