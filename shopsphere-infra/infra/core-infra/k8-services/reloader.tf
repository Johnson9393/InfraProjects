# Restarts app Deployments when a Kubernetes Secret they use changes.
# ESO refreshes the Secret from AWS (every 1h). Reloader rolls the pods
# so new env vars are loaded. Works on dev and prod. RBAC comes later.

resource "helm_release" "reloader" {
  name       = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  namespace  = kubernetes_namespace_v1.eso.metadata[0].name

  timeout = 600

  depends_on = [kubernetes_namespace_v1.eso]
}
