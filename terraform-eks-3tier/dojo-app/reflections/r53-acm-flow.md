# Route 53 + ACM Certificate Validation

## 1. What We Are Building

In our project, Route 53 and ACM are used together to:

1. Find our existing Route 53 hosted zone.
2. Create an ACM certificate for our application subdomain.
3. Create the DNS validation record required by ACM.
4. Wait for ACM to validate the certificate.
5. Later use the validated certificate with the HTTPS ALB.
6. Create a Route 53 Alias record that points our application domain to the ALB.

Overall flow:

    Route 53 Hosted Zone
          ↓
    ACM Certificate
          ↓
    ACM gives DNS validation information
          ↓
    Terraform creates validation CNAME
          ↓
    ACM checks the CNAME
          ↓
    Certificate becomes validated/issued
          ↓
    HTTPS ALB uses the certificate
          ↓
    Route 53 Alias points domain → ALB


# 2. Getting the Existing Hosted Zone

Our domain already exists in Route 53, so we don't create the hosted zone again.

We use a data source:

    data "aws_route53_zone" "dojo_hosted_zone" {
      name         = var.domain_name
      private_zone = false
    }

This means:

    "Find the existing public Route 53 hosted zone
     whose name matches var.domain_name."

For example:

    var.domain_name = "example.com"

Terraform finds:

    example.com
        ↓
    Route 53 Hosted Zone
        ↓
    zone_id

We can then use:

    data.aws_route53_zone.dojo_hosted_zone.zone_id

when creating Route 53 records.


# 3. ACM Certificate

We request the certificate:

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

If:

    sub_domain  = "dojo"
    domain_name = "example.com"

then the certificate is requested for:

    dojo.example.com

We choose:

    validation_method = "DNS"

because ACM needs proof that we control the domain.

ACM therefore provides DNS validation information that we can create in Route 53.


# 4. What Are domain_validation_options?

After requesting the certificate, ACM provides validation information through:

    aws_acm_certificate.dojo_cert.domain_validation_options

This is a collection of domain validation options.

A validation option contains information such as:

    domain_name
    resource_record_name
    resource_record_type
    resource_record_value

Conceptually, ACM might provide:

    domain_name:
    dojo.example.com

    resource_record_name:
    _abc123.dojo.example.com

    resource_record_type:
    CNAME

    resource_record_value:
    _xyz789.acm-validations.aws.


# 5. Why Are There Multiple Domain Validation Options?

A certificate can cover more than one domain.

For example, a certificate could cover:

    example.com
    dojo.example.com
    api.example.com

ACM can therefore provide validation information associated with the domains covered by the certificate.

Conceptually:

    domain_validation_options
    │
    ├── Domain 1
    │     ├── domain_name
    │     ├── resource_record_name
    │     ├── resource_record_type
    │     └── resource_record_value
    │
    ├── Domain 2
    │     ├── domain_name
    │     ├── resource_record_name
    │     ├── resource_record_type
    │     └── resource_record_value
    │
    └── Domain 3
          ├── domain_name
          ├── resource_record_name
          ├── resource_record_type
          └── resource_record_value

The important point:

    domain_validation_options

does NOT mean different validation methods such as:

    DNS
    Email
    HTTP

Instead, it contains validation information for the domains covered by the certificate.

Because we selected:

    validation_method = "DNS"

the information contains the DNS record ACM expects us to create.


# 6. Why Do We Use for_each?

Our Route 53 validation resource contains:

    resource "aws_route53_record" "dojo_cert_validation" {

      for_each = {
        for dvo in aws_acm_certificate.dojo_cert.domain_validation_options : dvo.domain_name => {
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          record = dvo.resource_record_value
        }
      }

      ...
    }

The reason for `for_each` is:

    ACM dynamically provides validation information
    ↓
    We don't manually know the record values beforehand
    ↓
    Terraform loops through the validation options
    ↓
    Creates a Route 53 record for each validation option


# 7. Breaking Down the for_each

The main part is:

    for dvo in aws_acm_certificate.dojo_cert.domain_validation_options

This means:

    "Go through every domain validation option
     provided by ACM."

`dvo` is simply a temporary variable representing the current validation option.

Then:

    dvo.domain_name => {

creates a map where the domain name is used as the key.

The value contains:

    {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }

Conceptually, Terraform builds something like:

    {
      "dojo.example.com" = {
        name   = "_abc123.dojo.example.com"
        type   = "CNAME"
        record = "_xyz789.acm-validations.aws."
      }
    }

Then `for_each` uses this map to create the Route 53 record.


# 8. Why Not Create the CNAME Manually?

We could manually create a record if we already knew the exact values.

But ACM dynamically generates the validation record information.

We therefore let Terraform take the values directly from ACM:

    ACM
      ↓
    domain_validation_options
      ↓
    Terraform for loop
      ↓
    Route 53 validation record

This makes the configuration dynamic and reusable.

We don't have to manually copy ACM's validation values.


# 9. What Does each.value Mean?

Inside the resource we have:

    name    = each.value.name
    type    = each.value.type
    records = [each.value.record]

`each.value` represents the value of the current `for_each` item.

We created the value as:

    {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }

Therefore:

    each.value.name

means:

    ACM's DNS validation record name

    each.value.type

means:

    ACM's DNS validation record type

    each.value.record

means:

    ACM's DNS validation record value

So Terraform creates the Route 53 record using the exact values ACM provided.


# 10. What Does the Route 53 Validation Record Look Like?

For example:

    Name:
    _abc123.dojo.example.com

    Type:
    CNAME

    Value:
    _xyz789.acm-validations.aws.

Terraform creates that record inside our existing Route 53 hosted zone.

This record is NOT for normal application traffic.

It is specifically for ACM certificate validation.


# 11. Why CNAME?

CNAME means:

    Canonical Name

A CNAME DNS record points one DNS name to another DNS name.

For ACM validation, ACM gives us a special validation hostname.

Example:

    _abc123.dojo.example.com
              ↓ CNAME
    _xyz789.acm-validations.aws.

ACM can then check that DNS record and use it to verify control of the domain.

The important distinction is:

    CNAME
      ↓
    Used here for ACM certificate validation

It is NOT being used to send normal application traffic to the ALB.


# 12. Why Does ACM Point to Another Domain?

The original domain is:

    dojo.example.com

We are proving:

    "I control dojo.example.com."

ACM gives us a unique DNS challenge.

For example:

    _abc123.dojo.example.com
              ↓
    _xyz789.acm-validations.aws.

We place that exact record in our Route 53 zone.

ACM then checks:

    "Does the required DNS record exist
     under the domain being validated?"

If it exists correctly, ACM can verify domain control.

Think of it as:

    You:
    "I control dojo.example.com."

    ACM:
    "Prove it by creating this exact DNS record."

    You:
    Create the CNAME in Route 53.

    ACM:
    Checks the CNAME.

    ACM:
    "Validation successful."


# 13. ACM Validation Record vs Application DNS Record

These are two completely different DNS records.

## ACM validation record

    _abc123.dojo.example.com
              ↓ CNAME
    _xyz789.acm-validations.aws.

Purpose:

    Prove domain control
    ↓
    Validate ACM certificate


## Application DNS record

Later we create:

    dojo.example.com
          ↓
       A Alias
          ↓
         ALB

Purpose:

    Send application traffic
    ↓
    AWS ALB

So:

    CNAME → ACM certificate validation

    A Alias → Application traffic to ALB


# 14. Why Do We Need aws_acm_certificate_validation?

Creating the Route 53 CNAME does NOT itself mean the ACM certificate has been validated.

We therefore have:

    resource "aws_acm_certificate_validation" "acm_validation" {
      certificate_arn         = aws_acm_certificate.dojo_cert.arn
      validation_record_fqdns = [
        for record in aws_route53_record.dojo_cert_validation : record.fqdn
      ]
    }

This tells Terraform:

    "Wait for ACM to actually validate the certificate
     using the DNS validation records."

The complete process is:

    1. Request ACM certificate
            ↓
    2. ACM provides DNS validation information
            ↓
    3. Terraform creates CNAME in Route 53
            ↓
    4. ACM checks the CNAME
            ↓
    5. ACM validates/issues certificate
            ↓
    6. HTTPS ALB can use the certificate


# 15. validation_record_fqdns

This part:

    validation_record_fqdns = [
      for record in aws_route53_record.dojo_cert_validation : record.fqdn
    ]

collects the fully qualified domain names of the Route 53 validation records created by our `for_each`.

Conceptually:

    Route 53 validation records
             ↓
    for each record
             ↓
    record.fqdn
             ↓
    List of validation record FQDNs

For example:

    [
      "_abc123.dojo.example.com."
    ]

Terraform gives those validation record names to the ACM certificate validation resource so ACM validation can be completed.


# 16. Why Is Certificate Validation Important for Our Ingress?

Our Ingress later contains:

    "alb.ingress.kubernetes.io/certificate-arn" =
      aws_acm_certificate.dojo_cert.arn

And our Ingress has:

    depends_on = [
      kubernetes_namespace.dojo,
      aws_acm_certificate_validation.acm_validation
    ]

This means:

    ACM certificate
          ↓
    DNS validation
          ↓
    Certificate validated
          ↓
    HTTPS Ingress
          ↓
    ALB HTTPS listener

We don't want the HTTPS ALB configuration to depend on a certificate that hasn't been successfully validated.


# 17. Final Route 53 + ACM Flow

The complete flow in our project is:

    Existing Route 53 Hosted Zone
             ↓
    data.aws_route53_zone
             ↓
    Find domain's hosted zone
             ↓
    ACM Certificate Request
             ↓
    ACM generates DNS validation information
             ↓
    domain_validation_options
             ↓
    Terraform for_each
             ↓
    Create ACM validation CNAME
             ↓
    ACM checks DNS record
             ↓
    aws_acm_certificate_validation
             ↓
    Certificate validated
             ↓
    HTTPS Ingress can use ACM certificate
             ↓
    ALB is created/configured by
    AWS Load Balancer Controller
             ↓
    aws_lb data source discovers the ALB
             ↓
    Route 53 A Alias
             ↓
    dojo.example.com → ALB


# 18. Easy Recall

Remember the three ACM/Route 53 pieces:

    aws_acm_certificate
        ↓
    "Request the certificate."

    aws_route53_record
        ↓
    "Create the DNS proof ACM asked for."

    aws_acm_certificate_validation
        ↓
    "Wait for ACM to accept that proof."


And remember the two DNS records in our application:

    CNAME
        ↓
    ACM validation
        ↓
    Prove domain control

    A Alias
        ↓
    ALB
        ↓
    Send application traffic


# 19. Useful Kubernetes Command for ALB Inspection

Once the Ingress exists, the complete Kubernetes Ingress object can be inspected using:

    kubectl get ingress <ingress-name> -n <namespace> -o json

This is useful when you need to understand where a value comes from instead of memorizing a deeply nested Terraform expression.

For example, the Ingress status can contain:

    "status": {
      "loadBalancer": {
        "ingress": [
          {
            "hostname": "k8s-dojo-xxxxx.us-east-1.elb.amazonaws.com"
          }
        ]
      }
    }

The ALB hostname can then be extracted using:

    kubectl get ingress <ingress-name> -n <namespace> \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

The general learning approach is:

    Inspect JSON
        ↓
    Understand the structure
        ↓
    Navigate to the required value
        ↓
    Build the Terraform expression