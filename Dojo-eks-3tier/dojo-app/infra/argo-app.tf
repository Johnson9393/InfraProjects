provider "argocd" {
  server_addr = "${var.argo_sub_domain}.${var.domain_name}"
  username    = "admin"
  password    = "TXeWABGNgjcwMppI"
}


resource "argocd_application" "argo_app" {
  metadata {
    name      = "argo-app"
    namespace = "argocd"
  }

  wait = true

  spec {
    project = "default"

    destination {
      server    = "https://kubernetes.default.svc"
    }

    source {
      repo_url        = "https://github.com/Johnson9393/InfraProjects/tree/main/Dojo-eks-3tier"
      path            = "Dojo-eks-3tier/dojo-app/k8s-services"
      target_revision = "main"
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}