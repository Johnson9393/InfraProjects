# -----------------------------------------------------------------------------
# Route 53 - DNS aliases for ShopSphere services
# -----------------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Wait for AWS Load Balancer Controller to populate
# the ALB hostname in Kubernetes Ingress status.
resource "time_sleep" "wait_for_service_ingress" {
  for_each = local.ingress_services

  depends_on      = [kubernetes_ingress_v1.service]
  create_duration = "180s"
}

# Read the Ingress resource to obtain its ALB hostname.
data "kubernetes_ingress_v1" "service" {
  for_each = local.ingress_services

  metadata {
    name      = "${each.key}-ingress"
    namespace = each.value.namespace
  }

  depends_on = [time_sleep.wait_for_service_ingress]
}

# Retrieve the ALB created by the AWS Load Balancer Controller.
data "aws_lb" "ingress" {
  tags = {
    Name        = "${var.app_subdomain}-ingress"
    ManagedBy   = "Terraform"
  }

  depends_on = [kubernetes_ingress_v1.service]
}

# Create Route 53 alias records pointing to the ALB.
resource "aws_route53_record" "service" {
  for_each = local.ingress_services

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.host
  type    = "A"

  alias {
    name = data.kubernetes_ingress_v1.service[each.key].status[0].load_balancer[0].ingress[0].hostname
    zone_id = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }

  depends_on = [data.kubernetes_ingress_v1.service]
}