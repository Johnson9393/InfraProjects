# Route 53 aliases for platform ingress (Argo CD, Grafana, Prometheus).
#
# kubernetes_ingress_v1.status is empty at create time. Sleep + depends_on
# does not refresh those attributes. Re-read Ingress after the ALB hostname
# exists, and take the ALB hosted zone from AWS (us-east-1 ALB zone
# Z35SXDOTRQ7X7K is correct, but the live ALB is the source of truth).

data "kubernetes_ingress_v1" "argocd" {
  count = local.deploy_argocd ? 1 : 0

  metadata {
    name      = kubernetes_ingress_v1.argocd_ingress_tls[0].metadata[0].name
    namespace = kubernetes_ingress_v1.argocd_ingress_tls[0].metadata[0].namespace
  }

  depends_on = [kubernetes_ingress_v1.argocd_ingress_tls]
}

data "kubernetes_ingress_v1" "grafana" {
  count = local.deploy_monitoring ? 1 : 0

  metadata {
    name      = kubernetes_ingress_v1.grafana_ingress[0].metadata[0].name
    namespace = kubernetes_ingress_v1.grafana_ingress[0].metadata[0].namespace
  }

  depends_on = [kubernetes_ingress_v1.grafana_ingress]
}

data "kubernetes_ingress_v1" "prometheus" {
  count = local.deploy_monitoring ? 1 : 0

  metadata {
    name      = kubernetes_ingress_v1.prometheus_ingress[0].metadata[0].name
    namespace = kubernetes_ingress_v1.prometheus_ingress[0].metadata[0].namespace
  }

  depends_on = [kubernetes_ingress_v1.prometheus_ingress]
}

data "aws_lb" "shared_ingress" {
  count = (local.deploy_argocd || local.deploy_monitoring) ? 1 : 0

  tags = {
    Name      = "${var.app_subdomain}-ingress"
    ManagedBy = "Terraform"
  }

  depends_on = [
    kubernetes_ingress_v1.argocd_ingress_tls,
    kubernetes_ingress_v1.grafana_ingress,
    kubernetes_ingress_v1.prometheus_ingress,
  ]
}

resource "aws_route53_record" "argocd" {
  count = local.deploy_argocd ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "argocd.${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.argocd[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.shared_ingress[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  count = local.deploy_monitoring ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana.${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.grafana[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.shared_ingress[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "prometheus" {
  count = local.deploy_monitoring ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "prometheus.${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.prometheus[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.shared_ingress[0].zone_id
    evaluate_target_health = true
  }
}
