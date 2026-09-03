# Get the domain name from the hosted zone using data source
data "aws_route53_zone" "dojo_hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# Create a Route 53 record to point the domain name to the ALB DNS name
resource "aws_route53_record" "dojo_alb_record" {
  zone_id = data.aws_route53_zone.dojo_hosted_zone.zone_id
  name    = "${var.sub_domain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}

# Create ACM certificate for the domain name to enable HTTPS on the ALB
resource "aws_acm_certificate" "dojo_cert" {
  domain_name       = "${var.sub_domain}.${var.domain_name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "dojo-cert"
  }
}

# created r53 record record for ACM certificate validation
resource "aws_route53_record" "dojo_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.dojo_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id = data.aws_route53_zone.dojo_hosted_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

#  The above block creates a Route 53 record for each domain validation option provided by the ACM certificate. It uses a for_each loop to iterate over the domain validation options and creates a DNS record for each one. The record is created in the hosted zone specified by the data source and uses the name, type, and value provided by the ACM certificate for validation. The TTL is set to 60 seconds to ensure that the validation record is quickly propagated across the DNS system.



# Validate the ACM certificate
resource "aws_acm_certificate_validation" "acm_validation" {
  certificate_arn         = aws_acm_certificate.dojo_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.dojo_cert_validation : record.fqdn]
}

