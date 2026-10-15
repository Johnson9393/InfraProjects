# Monitoring stack — deployed on dev only (see locals.deploy_monitoring).
# Prod uses dev Grafana/Prometheus URLs (grafana.*, prometheus.* on shared ALB).

resource "kubernetes_namespace_v1" "monitoring" {
  count = local.deploy_monitoring ? 1 : 0

  metadata {
    name = local.monitoring_namespace

    labels = {
      name       = local.monitoring_namespace
      managed-by = "terraform"
    }
  }
}


resource "helm_release" "kube_prometheus_grafana_stack" {
  count = local.deploy_monitoring ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring[0].metadata[0].name
  version    = "70.0.0"
  timeout    = 600

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          resources = {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
          retention                     = "15d"
          retentionSize                 = "10GB"
          serviceMonitorSelector          = {}
          serviceMonitorNamespaceSelector = {}
          podMonitorSelector              = {}
          podMonitorNamespaceSelector     = {}
          additionalScrapeConfigs         = []
          externalUrl                     = "https://prometheus.${var.app_subdomain}.${var.domain_name}"
          routePrefix                     = "/"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }
        }
        service = {
          type = "ClusterIP"
          port = 9090
        }
      }

      grafana = {
        enabled       = true
        adminPassword = "admin123"

        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }

        persistence = {
          enabled          = true
          storageClassName = "gp2"
          accessModes      = ["ReadWriteOnce"]
          size             = "10Gi"
        }

        service = {
          type = "ClusterIP"
          port = 80
        }

        sidecar = {
          datasources = {
            enabled                  = true
            defaultDatasourceEnabled = true
          }
        }

        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            access    = "proxy"
            url       = "http://loki.${local.monitoring_namespace}.svc.cluster.local:3100"
            isDefault = false
            editable  = true
          }
        ]

        dashboards = {
          default = {
            kubernetes-cluster = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            kubernetes-pods = {
              gnetId     = 6417
              revision   = 1
              datasource = "Prometheus"
            }
          }
        }

        "grafana.ini" = {
          server = {
            domain              = "grafana.${var.app_subdomain}.${var.domain_name}"
            root_url            = "https://grafana.${var.app_subdomain}.${var.domain_name}"
            serve_from_sub_path = false
          }
          analytics = {
            check_for_updates = false
          }
        }
      }

      nodeExporter = {
        enabled = true
      }

      kubeStateMetrics = {
        enabled = true
      }

      defaultRules = {
        create = true
        rules = {
          alertmanager                = true
          etcd                        = true
          configReloaders             = true
          general                     = true
          k8s                         = true
          kubeApiserverAvailability   = true
          kubeApiserverSlos           = true
          kubeControllerManager       = true
          kubelet                     = true
          kubeProxy                   = true
          kubePrometheusGeneral       = true
          kubePrometheusNodeRecording = true
          kubernetesApps              = true
          kubernetesResources         = true
          kubernetesStorage           = true
          kubernetesSystem            = true
          kubeSchedulerAlerting       = true
          kubeSchedulerRecording      = true
          kubeStateMetrics            = true
          network                     = true
          node                        = true
          nodeExporterAlerting        = true
          nodeExporterRecording       = true
          prometheus                  = true
          prometheusOperator          = true
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
  ]
}