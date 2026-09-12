# created namespace for argocd to install in this isolated namespace
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

#Install argocd using helm chart
resource "helm_release" "argocd" {
    name      = "argocd"
    repository = "https://argoproj.github.io/argo-helm"
    chart     = "argo-cd"
    version   = "7.7.16"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name


    set = [
        # Set the service type to ClusterIP so that it is not exposed outside the cluster
        {
            name = "server.service.type"
            value = "ClusterIP"
        },
        # Run insecure mode since ALB terminates SSL so that alb to argocd server is not encrypyted
        {
            name = "configs.params.server\\.insecure"
            value = "true"
        }
    ]
}




