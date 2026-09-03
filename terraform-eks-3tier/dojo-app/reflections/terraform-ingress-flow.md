# Terraform Kubernetes Ingress — ALB, Annotations & Outputs

## 1. What We Are Creating

Terraform creates a Kubernetes Ingress resource:

    resource "kubernetes_ingress_v1" "app_ingress_tls" {
      ...
    }

Important:

Terraform does NOT directly create the AWS ALB here.

The flow is:

    Terraform
       ↓
    Kubernetes Ingress
       ↓
    AWS Load Balancer Controller
       ↓
    AWS ALB

The AWS Load Balancer Controller watches the Ingress and creates/configures the ALB according to the Ingress configuration and annotations.

---

## 2. Metadata Block

The metadata block contains information about the Kubernetes Ingress.

    metadata {
      name      = "${var.app_subdomain}-ingress"
      namespace = var.app_namespace

      annotations = {
        ...
      }
    }

### name

Identifies the Ingress inside Kubernetes.

Example:

    student-ingress

We can use this name with commands such as:

    kubectl get ingress student-ingress -n dojo

### namespace

Specifies which Kubernetes namespace the Ingress belongs to.

Example:

    namespace = "dojo"

The Ingress will therefore exist inside the `dojo` namespace.

### annotations

Annotations are additional configuration instructions attached to the Kubernetes Ingress.

In our case, the annotations are mainly instructions for the AWS Load Balancer Controller about how the ALB should be created and configured.

Think:

    Ingress
       ↓
    Annotations
       ↓
    Instructions for ALB Controller
       ↓
    ALB configuration

---

# 3. ALB Annotations

## 3.1 ALB Scheme

    "alb.ingress.kubernetes.io/scheme" = "internet-facing"

Purpose:

Creates an Internet-facing/public ALB.

Flow:

    Internet
       ↓
    Internet-facing ALB
       ↓
    Kubernetes Services
       ↓
    Pods

The other common option is:

    "internal"

That is used when the ALB should be private/internal rather than Internet-facing.

Easy recall:

    internet-facing → public application
    internal        → private/internal application

---

## 3.2 Target Type

    "alb.ingress.kubernetes.io/target-type" = "ip"

Purpose:

Tells the ALB to register IP addresses as targets.

In our EKS setup, this means the ALB can target Pod IPs directly.

Flow:

    ALB
      ↓
    Pod IP
      ↓
    Container

This is different from targeting the worker nodes.

Easy recall:

    target-type = ip
        ↓
    ALB targets Pod IPs

---

## 3.3 ALB Listen Ports

    "alb.ingress.kubernetes.io/listen-ports" =
      "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"

Purpose:

Tells the ALB which listener ports to create.

This creates:

    ALB
     ├── HTTP  :80
     └── HTTPS :443

The HTTP and HTTPS listeners can then handle incoming application traffic.

---

## 3.4 SSL Redirect

    "alb.ingress.kubernetes.io/ssl-redirect" = "443"

Purpose:

Redirects HTTP requests to HTTPS.

Example:

    http://student.example.com
              ↓
          ALB redirect
              ↓
    https://student.example.com

This ensures users ultimately access the application through HTTPS.

---

## 3.5 ACM Certificate

    "alb.ingress.kubernetes.io/certificate-arn" =
      aws_acm_certificate.app.arn

Purpose:

Tells the ALB which ACM certificate should be used for the HTTPS listener.

Important distinction:

    ACM
      ↓
    provides/stores the certificate
      ↓
    ALB
      ↓
    uses the certificate
      ↓
    ALB terminates TLS

ACM itself does NOT terminate TLS.

The ALB performs the TLS termination using the certificate provided by ACM.

---

## 3.6 Health Check Path

    "alb.ingress.kubernetes.io/healthcheck-path" = "/health"

Purpose:

Tells the ALB which URL endpoint it should call to check whether a target is healthy.

Example:

    ALB
      ↓
    /health
      ↓
    Pod

If the application responds successfully, the target can be considered healthy.

The exact endpoint should exist in the application.

---

## 3.7 Health Check Protocol

    "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"

Purpose:

Tells the ALB HOW to make the health-check request.

The two concepts work together:

    healthcheck-path
        ↓
    WHERE should I check?
        ↓
    /health

    healthcheck-protocol
        ↓
    HOW should I check?
        ↓
    HTTP

So:

    HTTP + /health

means:

    ALB → HTTP request → /health → target

Health checks are separate from normal user requests and are performed by the ALB to determine target health.

---

## 3.8 Load Balancer Attributes

    "alb.ingress.kubernetes.io/load-balancer-attributes" =
      "idle_timeout.timeout_seconds=60"

Purpose:

Configures behavior/settings of the ALB itself.

Here we configure the ALB's idle connection timeout.

It means:

> If a connection has no data flowing for 60 seconds, the ALB can close that idle connection.

It does NOT mean:

    ❌ Wait 60 seconds before health checks
    ❌ Wait 60 seconds for the application to become stable
    ❌ Wait 60 seconds before forwarding traffic

It is about connection management.

Think:

    Health check
        ↓
    "Is my target healthy?"

    Load balancer attribute
        ↓
    "How should my ALB behave?"

There are other ALB attributes that can be configured in future depending on application requirements.

---

## 3.9 ALB Tags

    "alb.ingress.kubernetes.io/tags" =
      "Environment=production,ManagedBy=Terraform,Name=${var.app_subdomain}-ingress"

Purpose:

Adds AWS tags to the ALB.

Example:

    Environment = production
    ManagedBy   = Terraform
    Name        = student-ingress

Tags are useful for:

- Identifying resources
- Cost tracking
- Environment separation
- Automation
- Resource management

---

# 4. Easy Way to Remember ALB Annotations

Instead of memorizing every annotation individually, group them by purpose.

    ALB exposure
        ↓
    scheme

    Where traffic goes
        ↓
    target-type

    ALB entry points
        ↓
    listen-ports

    HTTPS behavior
        ↓
    ssl-redirect
    certificate-arn

    Target health
        ↓
    healthcheck-path
    healthcheck-protocol

    ALB behavior/settings
        ↓
    load-balancer-attributes

    Resource organization
        ↓
    tags

Overall:

    "How should my ALB be created and configured?"

---

# 5. wait_for_load_balancer

After the metadata block:

    wait_for_load_balancer = true

This is a Terraform Kubernetes provider setting.

It tells Terraform:

> After creating the Ingress, wait until the Load Balancer has been created and the Ingress receives its Load Balancer information.

The flow is:

    Terraform
       ↓
    Creates Ingress
       ↓
    AWS Load Balancer Controller sees Ingress
       ↓
    Controller creates ALB
       ↓
    ALB gets DNS hostname
       ↓
    Ingress status is updated
       ↓
    Terraform continues

It is therefore a synchronization/wait mechanism.

It does NOT itself create the ALB.

---

# 6. depends_on

Example:

    depends_on = [
      kubernetes_namespace.devopsdozo,
      aws_acm_certificate_validation.app
    ]

Purpose:

Explicitly tells Terraform that these resources should be ready before creating the Ingress.

The namespace dependency means:

    Namespace
       ↓
    Ingress

The certificate dependency means:

    ACM Certificate
       ↓
    DNS validation
       ↓
    Certificate validated
       ↓
    Ingress

`depends_on` is useful when Terraform needs an explicit creation-order relationship that may not otherwise be obvious.

For our project, the namespace/resource names will be changed to match our actual `dojo` resources.

---

# 7. spec Block

The `spec` block defines the desired behavior of the Ingress.

Example:

    spec {
      ingress_class_name = "alb"

      rule {
        ...
      }
    }

Think:

    metadata
        ↓
    Information + ALB instructions

    spec
        ↓
    Actual Ingress behavior/routing

---

# 8. ingress_class_name

    ingress_class_name = "alb"

Purpose:

Associates this Ingress with the `alb` IngressClass.

This tells Kubernetes which Ingress controller should handle this Ingress.

Our flow:

    Terraform
       ↓
    Kubernetes Ingress
       ↓
    ingressClassName = alb
       ↓
    AWS Load Balancer Controller
       ↓
    AWS ALB

Important:

`alb` here is NOT the name of the AWS ALB.

It is the name of the Kubernetes IngressClass used for ALB-based Ingress handling.

---

# 9. rule Block

Example:

    rule {
      host = "${var.app_subdomain}.${var.domain_name}"

      http {
        ...
      }
    }

A rule defines which incoming request this routing configuration applies to.

For example:

    var.app_subdomain = "student"
    var.domain_name   = "example.com"

produces:

    student.example.com

Therefore:

    host = "student.example.com"

means:

> When a request comes to this hostname, apply the routing rules inside this rule.

Conceptually:

    Incoming request
          ↓
    student.example.com
          ↓
       host matches
          ↓
         rule
          ↓
       check path

This allows different hosts/subdomains to have different routing rules.

For example:

    student.example.com → Student Portal
    admin.example.com   → Admin Portal
    api.example.com     → API

---

# 10. HTTP Block

Inside the rule:

    http {
      ...
    }

This defines the HTTP path-routing configuration.

Inside it, we define `path` blocks.

---

# 11. Backend API Path

Example:

    path {
      path      = "/api"
      path_type = "Prefix"

      backend {
        service {
          name = kubernetes_service.backend_service.metadata[0].name

          port {
            number = 8080
          }
        }
      }
    }

The path:

    /api

means:

> Requests whose URL starts with `/api` should follow this routing rule.

Examples that match:

    /api
    /api/
    /api/users
    /api/login
    /api/questions/10

Because:

    path_type = "Prefix"

means the path and everything underneath that path is matched.

---

# 12. Ingress Backend

The `backend` block defines the destination for a matching request.

Important:

`backend` here does NOT mean "the application's backend."

It means:

> The destination where the Ingress sends matching traffic.

For our `/api` rule:

    /api
      ↓
    backend
      ↓
    backend-service:8080
      ↓
    Backend Pods

The Ingress sends traffic to the Kubernetes Service.

The Service then selects the appropriate Pods.

---

# 13. Referencing the Kubernetes Service

Example:

    name = kubernetes_service.backend_service.metadata[0].name

This means:

> Get the actual name of the Kubernetes Service that Terraform created for our backend.

Breaking it down:

    kubernetes_service
        ↓
    Terraform Kubernetes Service resource

    backend_service
        ↓
    Our Terraform local resource name

    metadata
        ↓
    Service metadata

    [0]
        ↓
    First item in the provider's metadata collection

    name
        ↓
    Actual Kubernetes Service name

If the Service is:

    backend-service

the expression returns:

    backend-service

This avoids hard-coding the Service name.

---

# 14. Service Port

Example:

    port {
      number = 8080
    }

This tells the Ingress to send the matching traffic to port `8080` of the Kubernetes Service.

Therefore:

    /api
      ↓
    backend-service:8080
      ↓
    Backend Pods

Similarly, the frontend path uses:

    /
      ↓
    frontend-service:80
      ↓
    Frontend Pods

---

# 15. Frontend Path

Example:

    path {
      path      = "/"
      path_type = "Prefix"

      backend {
        service {
          name = kubernetes_service.frontend_service.metadata[0].name

          port {
            number = 80
          }
        }
      }
    }

Because `/` is a Prefix, it acts as the default path for requests that don't match the more specific `/api` path.

So:

    /api/users
        ↓
    backend-service:8080

    /login
        ↓
    frontend-service:80

    /dashboard
        ↓
    frontend-service:80

    /
        ↓
    frontend-service:80

The more specific `/api` rule takes precedence over `/`.

---

# 16. Complete Ingress Routing Flow

Our eventual architecture is:

    Internet
       ↓
    HTTPS :443
       ↓
    AWS ALB
       ↓
    Host: student.example.com
       ↓
    Path matching
       │
       ├── /api/*
       │      ↓
       │  backend-service:8080
       │      ↓
       │  Backend Pods
       │      ↓
       │  RDS
       │
       └── /*
              ↓
          frontend-service:80
              ↓
          Frontend Pods

---

# 17. Terraform Output

The tutor's example has:

    output "ingress_tls_hostname" {
      description = "The ALB hostname for the TLS ingress"

      value = try(
        kubernetes_ingress_v1.app_ingress_tls.status[0].load_balancer[0].ingress[0].hostname,
        "pending"
      )
    }

An output does NOT create a resource.

It tells Terraform:

> Show me this value after Terraform has created the resources.

Here, we want the ALB's DNS hostname.

Example:

    ingress_tls_hostname =
      "k8s-dojo-123456789.us-east-1.elb.amazonaws.com"

This hostname is useful when inspecting the ALB and when connecting DNS such as Route 53 to the ALB.

---

# 18. Where Does the ALB Hostname Come From?

The hostname ultimately comes from the Kubernetes Ingress status.

After the AWS Load Balancer Controller creates the ALB, the Ingress status is updated.

Conceptually, the Ingress JSON looks like:

    {
      "apiVersion": "networking.k8s.io/v1",
      "kind": "Ingress",
      "metadata": {
        "name": "student-ingress",
        "namespace": "dojo"
      },
      "spec": {
        "ingressClassName": "alb"
      },
      "status": {
        "loadBalancer": {
          "ingress": [
            {
              "hostname": "k8s-dojo-123456789.us-east-1.elb.amazonaws.com"
            }
          ]
        }
      }
    }

The important part is:

    status
      ↓
    loadBalancer
      ↓
    ingress
      ↓
    hostname

---

# 19. How to Inspect the Complete Ingress JSON

You do NOT need to memorize the Terraform expression.

First inspect the actual Kubernetes object:

    kubectl get ingress <ingress-name> -n <namespace> -o json

For our project, for example:

    kubectl get ingress student-ingress -n dojo -o json

This gives the complete JSON returned by Kubernetes.

Then inspect the structure and navigate through it.

For example:

    status
      ↓
    loadBalancer
      ↓
    ingress
      ↓
    hostname

This is a useful troubleshooting/learning approach:

> If you don't know how to reference a nested Kubernetes value, inspect the object's JSON first and follow its structure.

---

# 20. Extract Only the ALB Hostname

Once the structure is understood, Kubernetes `jsonpath` can directly extract the hostname:

    kubectl get ingress student-ingress -n dojo \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Result:

    k8s-dojo-123456789.us-east-1.elb.amazonaws.com

This is useful for quickly checking whether the ALB hostname has been populated.

---

# 21. Building the Terraform Expression From the JSON

The Terraform expression:

    kubernetes_ingress_v1.app_ingress_tls.status[0].load_balancer[0].ingress[0].hostname

is simply navigating through the Terraform representation of the same nested structure.

Think:

    Terraform Ingress resource
            ↓
    status
            ↓
    [0]
            ↓
    load_balancer
            ↓
    [0]
            ↓
    ingress
            ↓
    [0]
            ↓
    hostname

Eventually:

    k8s-dojo-123456789.us-east-1.elb.amazonaws.com

The exact Terraform nesting uses the structure exposed by the Terraform Kubernetes provider, which is why the provider-specific `[0]` indexes appear.

---

# 22. Terraform try() Function

Terraform provides the `try()` function for safely evaluating expressions that may produce an error.

Syntax:

    try(expression, fallback)

Example:

    try(
      kubernetes_ingress_v1.app_ingress_tls.status[0].load_balancer[0].ingress[0].hostname,
      "pending"
    )

Meaning:

> Try to get the ALB hostname. If evaluating that expression produces an error, use `"pending"` instead.

Conceptually:

    Can Terraform get hostname?
           │
       ┌───┴───┐
       │       │
      YES     ERROR
       │       │
       ↓       ↓
    hostname  pending

---

# 23. Why Use "pending"?

`"pending"` is just a value we chose as a fallback.

It is NOT an AWS status.

It does NOT mean AWS officially returned the word `pending`.

It simply means:

> The hostname wasn't available when Terraform evaluated this expression, so show `pending` instead of failing the output evaluation.

Example:

    ingress_tls_hostname = "pending"

Later, when the hostname is available:

    ingress_tls_hostname =
      "k8s-dojo-123456789.us-east-1.elb.amazonaws.com"

---

# 24. Final Mental Model

The entire Terraform Ingress resource can be remembered like this:

    resource
       ↓
    Create Kubernetes Ingress
       ↓
    metadata
       ↓
    Name + namespace + ALB instructions
       ↓
    wait_for_load_balancer
       ↓
    Wait for Load Balancer information
       ↓
    depends_on
       ↓
    Control required creation order
       ↓
    spec
       ↓
    Define Ingress behavior
       ↓
    ingress_class_name = "alb"
       ↓
    Use ALB controller
       ↓
    rule
       ↓
    Which hostname?
       ↓
    http
       ↓
    Which URL path?
       ↓
    backend
       ↓
    Which Kubernetes Service?
       ↓
    ALB Controller
       ↓
    AWS ALB

And the output:

    Kubernetes Ingress status
       ↓
    Load Balancer information
       ↓
    ALB hostname
       ↓
    Terraform output

The most important practical idea is:

    Don't memorize deeply nested expressions.

    Inspect the Kubernetes JSON:
    
    kubectl get ingress <name> -n <namespace> -o json

    Then follow the JSON structure to find the value you need.