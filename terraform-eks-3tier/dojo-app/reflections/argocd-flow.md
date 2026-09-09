# Argo CD Installation and ALB Exposure

## What I Learned

In this phase, I learned how we install Argo CD inside our EKS cluster using Terraform and Helm, configure how the Argo CD Server is exposed inside Kubernetes, and expose Argo CD externally through our existing AWS Load Balancer Controller and ALB.

The complete high-level flow is:

Internet → HTTPS → ALB → TLS termination → HTTP inside VPC → Argo CD Ingress → argocd-server ClusterIP Service → Argo CD Pods

The main idea is:

- Argo CD runs inside our EKS cluster.
- Terraform manages the Argo CD installation.
- Helm is used to install Argo CD.
- The Argo CD Helm chart contains the Kubernetes resources and configurations required to install Argo CD.
- Terraform overrides selected Helm values using the `set` block.
- The Argo CD Server Service is configured as `ClusterIP`.
- Argo CD is therefore internally exposed inside Kubernetes rather than directly exposed to the Internet.
- The AWS ALB is the public entry point.
- HTTPS/TLS is terminated at the ALB.
- The ALB communicates with the internal Argo CD Service using HTTP.
- The AWS Load Balancer Controller watches the Argo CD Ingress and configures the ALB.
- The Argo CD Ingress can reuse our existing application ALB through an IngressGroup.
- Route53 provides DNS for the Argo CD subdomain.
- ACM provides the TLS certificate used by the ALB.

---

## 1. Create the Argo CD Namespace

Terraform first creates a dedicated Kubernetes namespace:

`argocd`

Resource:

`kubernetes_namespace_v1.argocd`

The purpose of the namespace is to keep Argo CD resources organized and separated from other Kubernetes workloads.

The cluster structure is conceptually:

EKS Cluster → argocd namespace → Argo CD resources

Our application continues to run in the `dojo` namespace.

---

## 2. Install Argo CD Using Helm

Terraform uses the `helm_release` resource to install Argo CD.

Important configuration:

- Helm release name: `argocd`
- Helm repository: `https://argoproj.github.io/argo-helm`
- Helm chart: `argo-cd`
- Helm chart version: `7.7.16`
- Namespace: `argocd`

The installation flow is:

Terraform → Helm → Argo CD Helm Chart → Kubernetes Resources → Argo CD running inside EKS

A Helm chart is a packaged collection of Kubernetes templates and configuration values required to install an application.

Therefore, we do not manually create every Argo CD Kubernetes resource.

Instead, Helm uses the Argo CD chart to create the required Kubernetes resources.

The chart version is pinned so that the installation is reproducible.

---

## 3. What the Helm `set` Block Does

The Argo CD Helm chart already contains default configuration values.

Terraform overrides selected values using the `set` block.

We override two important settings:

- `server.service.type = ClusterIP`
- `configs.params.server.insecure = true`

The mental model is:

Argo CD Helm Chart → Default Values → Terraform `set` Overrides → Customized Argo CD Installation

We do not need to memorize every Helm value path.

The important concept is:

Use the Helm chart's configuration values to change the behavior of the installation.

---

## 4. `server.service.type = ClusterIP`

The first override is:

`server.service.type = ClusterIP`

This configures the Kubernetes Service in front of the Argo CD Server to use the `ClusterIP` type.

The Argo CD Server itself runs inside Kubernetes Pods.

The `argocd-server` Kubernetes Service provides a stable network endpoint for those Pods.

Using ClusterIP means the Service is internal to the Kubernetes cluster.

The architecture becomes:

Internet → ALB → argocd-server ClusterIP Service → Argo CD Pods

We do not expose the Argo CD Service directly to the Internet.

Instead, the ALB acts as the public entry point.

Important distinction:

The Argo CD Server is the application component running in Pods.

`argocd-server` is the Kubernetes Service in front of those Pods.

`ClusterIP` controls how that Service is exposed.

---

## 5. `server.insecure = true`

The second override is:

`configs.params.server.insecure = true`

This tells the Argo CD Server to accept HTTP instead of expecting HTTPS/TLS on its incoming connection.

The reason is that TLS is terminated at the ALB.

Our architecture is:

Browser → HTTPS/TLS → ALB → TLS termination → HTTP → argocd-server → Argo CD Pods

The browser establishes HTTPS with the ALB.

The ALB presents the ACM certificate and handles the TLS connection.

After TLS termination, the ALB communicates with the internal Argo CD Service using HTTP.

Therefore, Argo CD does not need to establish another TLS connection for the ALB-to-Argo-CD leg in our current architecture.

Important distinction:

`ClusterIP` → controls Service exposure.

`server.insecure = true` → tells Argo CD Server to expect HTTP rather than HTTPS.

Also, private networking and encryption are different concepts.

The ALB-to-Argo-CD traffic is private within the AWS/VPC networking path, but it is currently HTTP rather than TLS-encrypted.

---

# 6. Why We Need an Ingress

Because `argocd-server` is a ClusterIP Service, it is not directly exposed to the Internet.

We therefore create a Kubernetes Ingress for Argo CD.

The purpose of this Ingress is to define how Argo CD should be exposed through the AWS ALB.

The relationship is:

Kubernetes Ingress → AWS Load Balancer Controller → AWS ALB

The Ingress itself is not the ALB.

The AWS Load Balancer Controller watches the Ingress and configures the AWS ALB according to the Ingress definition.

---

# 7. Reusing the Existing ALB

We already have the AWS Load Balancer Controller installed for our three-tier application.

We do not need another AWS Load Balancer Controller for Argo CD.

The Argo CD Ingress uses the annotation:

`alb.ingress.kubernetes.io/group.name = var.alb_group_name`

This allows the Argo CD Ingress to join the same ALB IngressGroup as our existing application Ingress.

Therefore, the same ALB can handle both application and Argo CD traffic.

Conceptually:

Existing ALB → Application Ingress → Frontend/Backend

Existing ALB → Argo CD Ingress → argocd-server

The ALB can use hostname and path-based rules to send traffic to the appropriate destination.

Without the same IngressGroup configuration, the Argo CD Ingress could result in a separate ALB.

---

# 8. Internet-Facing ALB

The Argo CD Ingress contains:

`alb.ingress.kubernetes.io/scheme = internet-facing`

This tells the AWS Load Balancer Controller that the ALB should be Internet-facing.

The ALB becomes the public entry point for Argo CD.

The architecture is:

Internet → Internet-facing ALB → Argo CD Ingress → argocd-server

The Argo CD Service itself remains a ClusterIP Service.

---

# 9. ALB Target Type

The Ingress uses:

`alb.ingress.kubernetes.io/target-type = ip`

This configures the ALB to target Kubernetes Pod IPs.

This fits with the Kubernetes networking model we already learned:

ALB → Service → EndpointSlice → Pod

EndpointSlices contain the current Pod destinations associated with a Kubernetes Service.

---

# 10. HTTPS and TLS Configuration

The Argo CD Ingress configures the ALB to listen on HTTP port 80 and HTTPS port 443.

The SSL redirect configuration redirects HTTP traffic to HTTPS.

The ACM certificate is attached to the HTTPS listener.

Therefore:

Browser → HTTPS → ALB

The ALB uses the ACM certificate to establish the TLS connection with the browser.

TLS then terminates at the ALB.

After TLS termination:

ALB → HTTP → Argo CD Ingress → argocd-server

This is the same TLS termination architecture we learned earlier with our three-tier application.

---

# 11. Argo CD Ingress Routing

The Argo CD Ingress contains a `/` path.

That path routes to:

Service: `argocd-server`

Port: `80`

Therefore, requests arriving for the Argo CD hostname are routed to the Argo CD Server Service.

The request flow is:

Browser → HTTPS → ALB → Argo CD Ingress → argocd-server:80 → Argo CD Pods

The Kubernetes Service then performs the normal Service-to-Pod routing.

---

# 12. ACM Certificate

Terraform creates an ACM certificate for the Argo CD subdomain.

The certificate uses DNS validation.

The certificate is then associated with the ALB through the Ingress configuration.

The certificate allows the ALB to establish HTTPS/TLS with the browser.

The flow is:

Browser requests `https://argocd.<domain>`

→ Route53 resolves the hostname

→ Request reaches the ALB

→ ALB presents the ACM certificate

→ Browser validates the certificate

→ TLS session is established

→ ALB terminates TLS

→ ALB sends HTTP traffic internally toward Argo CD

---

# 13. Route53

Terraform also manages Route53 records.

Route53 has two important responsibilities in this setup:

1. DNS validation of the ACM certificate.
2. DNS resolution of the Argo CD subdomain to the ALB.

The final DNS flow is:

`argocd.<domain>` → Route53 → ALB

Therefore, users access Argo CD through the configured domain name instead of directly using the ALB DNS name.

---

# 14. ALB Health Check

The Argo CD Ingress configures the ALB health check path as:

`/`

The ALB uses this endpoint to determine whether the Argo CD target is healthy.

If a target is unhealthy, the ALB will not send normal traffic to that unhealthy target.

---

# 15. Terraform Dependencies

The Argo CD Ingress depends on several resources.

The important dependencies are:

- Argo CD namespace must exist.
- Argo CD Helm release must be installed.
- ACM certificate must be validated.
- AWS Load Balancer Controller must already be available in the cluster.

This ensures the required components exist before Terraform attempts to expose Argo CD through the ALB.

---

# 16. Complete Installation and Exposure Flow

The complete flow is:

Terraform

→ creates the `argocd` namespace

→ installs the Argo CD Helm chart

→ Helm creates the required Argo CD Kubernetes resources

→ Terraform overrides selected Helm values

→ Argo CD Server Service uses ClusterIP

→ Argo CD Server accepts HTTP internally

→ Terraform creates the Argo CD Ingress

→ AWS Load Balancer Controller watches the Ingress

→ Controller configures the existing ALB

→ Route53 provides the Argo CD DNS record

→ ACM provides the TLS certificate

→ Browser connects using HTTPS

→ ALB terminates TLS

→ ALB sends HTTP traffic internally

→ Argo CD Ingress routes traffic to `argocd-server`

→ `argocd-server` routes traffic to Argo CD Pods

---

# 17. Final Architecture

The final architecture is:

Internet

→ HTTPS/TLS

→ Existing Internet-facing ALB

→ TLS termination

→ HTTP inside the VPC

→ Argo CD Ingress

→ `argocd-server` ClusterIP Service

→ EndpointSlice

→ Argo CD Server Pod

The key security/networking mental model is:

Public Internet traffic is protected using HTTPS/TLS up to the ALB.

The ALB is the public entry point.

TLS terminates at the ALB.

After TLS termination, traffic remains inside the AWS/VPC networking path toward the internal Kubernetes Service.

The internal Service is not directly Internet-facing.

---

# 18. Core Responsibilities

Terraform:

Manages infrastructure and configuration.

Helm:

Installs Argo CD using the Argo CD Helm chart.

Helm Chart:

Provides the Kubernetes resources and default configuration required to install Argo CD.

Kubernetes:

Runs Argo CD and provides the internal `argocd-server` Service.

Ingress:

Defines how Argo CD should be exposed and routed.

AWS Load Balancer Controller:

Watches the Kubernetes Ingress and configures the AWS ALB.

ALB:

Acts as the public entry point and terminates TLS.

ACM:

Provides the TLS certificate used by the ALB.

Route53:

Provides DNS for the Argo CD subdomain and DNS validation for ACM.

---

# 19. Most Important Mental Model

The most important architecture learned from this `ArgoCD.tf` file is:

Terraform -> Helm → Argo CD inside EKS

and for external access:

Internet → HTTPS → ALB → TLS termination → HTTP inside VPC → Ingress → ClusterIP Service → Argo CD Pods

This completes the Argo CD installation and external-access portion.

The next major phase is the actual GitOps flow:

Git Repository → Argo CD → Kubernetes

That is where Argo CD connects to Git, identifies the desired Kubernetes state, detects changes, and synchronizes that desired state into the EKS cluster.