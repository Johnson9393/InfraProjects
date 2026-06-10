# Get the domain name from the hosted zone using data source
data "aws_route53_zone" "sp_hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# Create a Route 53 record to point the domain name to the ALB DNS name
resource "aws_route53_record" "sp_alb_record" {
  zone_id = data.aws_route53_zone.sp_hosted_zone.zone_id
  name    = "studentapp.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_alb.sp_alb.dns_name
    zone_id                = aws_alb.sp_alb.zone_id
    evaluate_target_health = true
  }
}

# Create ACM certificate for the domain name to enable HTTPS on the ALB
resource "aws_acm_certificate" "sp_cert" {
  domain_name       = "studentapp.${var.domain_name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "sp-cert"
  }
}

# DNS validation record for ACM certificate
resource "aws_route53_record" "sp_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sp_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.sp_hosted_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

#  The above block creates a Route 53 record for each domain validation option provided by the ACM certificate. It uses a for_each loop to iterate over the domain validation options and creates a DNS record for each one. The record is created in the hosted zone specified by the data source and uses the name, type, and value provided by the ACM certificate for validation. The TTL is set to 60 seconds to ensure that the validation record is quickly propagated across the DNS system.

