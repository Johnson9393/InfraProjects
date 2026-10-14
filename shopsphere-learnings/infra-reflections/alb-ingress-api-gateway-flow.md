# ShopSphere — DNS, ALB Controller & Kubernetes Ingress

## 1. Objective

Configure external access to ShopSphere through Route 53, AWS Application Load Balancer (ALB), and Kubernetes Ingress, with HTTPS enabled using ACM certificates.

The goal is to route client requests to the correct Kubernetes services using host-based routing.

## 2. Implementation Overview

- **Route 53:** Resolves application domain names to the ALB.
- **AWS Load Balancer Controller:** Watches Kubernetes Ingress resources and provisions/configures the AWS ALB.
- **Kubernetes Ingress:** Defines host-based routing rules and backend Kubernetes Services.
- **ACM:** Provides the TLS certificate used for HTTPS.
- **Kubernetes Services:** Forward traffic to the appropriate application Pods.
- **Frontend NGINX:** Serves the frontend and forwards API requests to the API Gateway hostname.

## 3. Important Terraform Files

| File | Responsibility |
|---|---|
| `locals.tf` | Defines environment-specific ingress configuration, hostnames, paths, and services. |
| `ingress.tf` | Creates Kubernetes Ingress resources and ALB annotations, including HTTPS and backend routing. |
| `route53.tf` | Waits for Ingress provisioning, reads the ALB hostname, and creates Route 53 alias records. |
| `acm.tf` | Looks up the Route 53 hosted zone and supports certificate-related configuration. |
| `versions.tf` | Defines Terraform providers and version constraints, including the `time` provider required for the delay resource. |

These files are in the ShopSphere App Infra Terraform configuration.

## 4. Request Flow: Client to Application

### Scenario A: Client opens the frontend

Client requests `https://shop.dev.infralabx.space/`.

1. **DNS resolution:** The browser resolves `shop.dev.infralabx.space`. Route 53 returns the ALB address through an alias record.
2. **HTTPS connection:** The browser connects to the ALB over HTTPS. The ALB uses the ACM certificate to terminate TLS.
3. **Ingress routing:** The ALB evaluates the host and path rules configured through Kubernetes Ingress.
4. **Kubernetes Service:** The request is forwarded to the frontend Kubernetes Service.
5. **Frontend Pod:** The frontend application, served through NGINX, returns the page to the client.

### Scenario B: Frontend sends an API request

When the frontend needs backend data:

1. Frontend NGINX forwards the API request to `https://api.dev.infralabx.space`.
2. Route 53 resolves this API hostname to the same shared ALB.
3. The ALB evaluates the API hostname against its Ingress routing rules.
4. The request reaches the API Gateway Kubernetes Service.
5. The API Gateway routes the request to the appropriate backend microservice.

**Key distinction:** The frontend hostname routes to the frontend Service, whereas the API hostname routes directly to the API Gateway Service. Both hostnames can use the same ALB.

## 5. How Terraform Connects Ingress and Route 53

The implementation follows this sequence:

1. `ingress.tf` creates `kubernetes_ingress_v1.service` resources for the configured services.
2. `route53.tf` uses `time_sleep.wait_for_service_ingress` with a 180-second delay after Ingress creation.
3. `data.kubernetes_ingress_v1.service` reads the provisioned Ingress and its ALB hostname.
4. `data.aws_elb_hosted_zone_id.main` retrieves the ALB's Route 53 hosted-zone ID.
5. `aws_route53_record.service` creates alias records pointing the application hostnames to the ALB.

The delay gives the AWS Load Balancer Controller time to provision the ALB and populate the Ingress status. It is a practical delay, not a guarantee that provisioning has completed; the resulting resources must still be verified.

## 6. Practical Verification Commands

Run these commands against the appropriate AWS account and Kubernetes cluster.

**Check Ingress resources:**

`kubectl get ingress -A`

**Inspect the frontend Ingress:**

`kubectl describe ingress dev-frontend-ingress -n shopsphere-dev`

**Inspect the API Gateway Ingress:**

`kubectl describe ingress dev-api-gateway-ingress -n shopsphere-dev`

**Check Kubernetes Services and Pods:**

`kubectl get svc,pods -n shopsphere-dev`

**Inspect DNS resolution:**

`dig shop.dev.infralabx.space`

`dig api.dev.infralabx.space`

**Check the HTTPS frontend response:**

`curl -I https://shop.dev.infralabx.space/`

**Check the API hostname's HTTPS response:**

`curl -I https://api.dev.infralabx.space/`

An HTTP status such as `200`, `301`, `302`, or even an application-level `401` can be valid depending on the endpoint and configuration. Investigate connection errors, unexpected redirects, DNS failures, or `5xx` responses.

## 7. Files to Check When Troubleshooting

- **DNS does not resolve:** Check the Route 53 records in `route53.tf` and the hosted zone referenced in `acm.tf`.
- **ALB is missing:** Check `ingress.tf`, the AWS Load Balancer Controller, and the Kubernetes Ingress status.
- **HTTPS or certificate errors:** Check the ACM certificate, certificate validation, and Ingress TLS configuration.
- **Frontend does not load:** Check the frontend Ingress, Service, Pods, and NGINX configuration.
- **Frontend loads but API requests fail:** Check the NGINX API forwarding configuration, API hostname resolution, API Gateway Ingress, Service, and backend application logs.

## 8. Key Takeaway

Route 53 resolves the application hostnames to the ALB. The AWS Load Balancer Controller manages the ALB based on Kubernetes Ingress resources. The ALB routes requests to the correct Kubernetes Services using host-based rules, and the Services forward traffic to the application Pods.

This establishes the external HTTPS entry point for ShopSphere before proceeding with the next application deployment and GitOps phases.