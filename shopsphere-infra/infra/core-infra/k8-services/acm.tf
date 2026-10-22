# Wildcard ACM for this env: *.<env>.infralabx.space (dev and prod each get one).

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "env" {
  count             = local.deploy_acm ? 1 : 0
  domain_name       = "*.${local.env_dns_suffix}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.env}-shopsphere-wildcard"
    Environment = var.env
    Application = "shopsphere"
  }
}

#Creates the DNS validation record inside Route 53.
resource "aws_route53_record" "cert_validation" {
  for_each = local.deploy_acm ? {
    for dvo in aws_acm_certificate.env[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

#Waits for ACM to verify that DNS record and confirm that the certificate is validated.
resource "aws_acm_certificate_validation" "env" {
  count           = local.deploy_acm ? 1 : 0
  certificate_arn = aws_acm_certificate.env[0].arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation :
    record.fqdn
  ]
}