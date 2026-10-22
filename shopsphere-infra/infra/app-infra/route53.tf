# -----------------------------------------------------------------------------
# Route 53 - DNS aliases for ShopSphere services
# -----------------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Shared ALB already exists from k8-services (same Name/ManagedBy tags
# and group.name). Do not read Kubernetes Ingress status — those
# backends do not exist until Argo CD deploys the app.
data "aws_lb" "ingress" {
  count = length(local.ingress_services) > 0 ? 1 : 0

  tags = {
    Name      = "${var.env}-${var.app_subdomain}-ingress"
    ManagedBy = "Terraform"
  }
}

resource "aws_route53_record" "service" {
  for_each = local.ingress_services

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.host
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress[0].dns_name
    zone_id                = data.aws_lb.ingress[0].zone_id
    evaluate_target_health = false
  }

  depends_on = [kubernetes_ingress_v1.service]
}