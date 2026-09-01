# EKS Ingress + AWS Load Balancer Controller — Learning Notes

## 1. Purpose

Ingress provides the external HTTP/HTTPS routing layer for the Kubernetes application.

For our 3-tier Dojo application:

Internet
→ AWS ALB
→ Ingress routing rules
→ Kubernetes Services
→ Pods
→ RDS

The frontend and backend Services can remain `ClusterIP` because the ALB is the external entry point.

---

## 2. What Is Ingress?

Ingress is a Kubernetes resource containing HTTP/HTTPS routing rules.

It answers:

"What traffic should go to which Kubernetes Service?"

Example:

`/` → `frontend-service`

`/api/*` → `backend-service`

Ingress does not itself receive traffic and does not implement the routing.

It is the desired routing configuration.

---

## 3. What Is an Ingress Controller?

An Ingress object alone does nothing.

A controller must watch the Kubernetes API for Ingress resources and implement the declared rules.

General model:

Ingress
→ defines desired routing
→ Ingress Controller watches it
→ Controller implements the desired state

Different controllers can implement Ingress, such as NGINX or AWS Load Balancer Controller.

For this project, we use the AWS Load Balancer Controller.

Therefore we do NOT need a separate NGINX Ingress Controller.

---

## 4. AWS Load Balancer Controller

The AWS Load Balancer Controller runs inside the EKS cluster as a Kubernetes workload.

It continuously watches Kubernetes resources such as Ingress.

When an Ingress is created or changed, the controller reconciles the desired Kubernetes configuration with the actual AWS infrastructure.

Example:

Desired state:

`/api/* → backend-service`

Controller:

→ detects the Ingress rule
→ calls AWS APIs
→ creates/updates ALB
→ configures listener/routing rules
→ connects traffic to the Kubernetes workload

The controller is mainly part of the control/reconciliation flow. It is not simply a proxy sitting in the application's request path.

---

## 5. Reconciliation

Reconciliation means:

"Compare desired state with actual state and correct differences."

Example:

Desired:

`/api/* → backend`

Actual ALB:

`/api/*` rule is missing

Controller detects the difference and recreates the rule.

This eventually results in:

Desired state = Actual state

This reconciliation pattern is fundamental to Kubernetes.

---

## 6. ALB vs Ingress

These are different things:

Ingress:

"What routing rules do I want?"

AWS Load Balancer Controller:

"How do I implement those rules in AWS?"

ALB:

"Where the external HTTP/HTTPS traffic is actually received and routed."

Mental model:

Ingress
→ AWS Load Balancer Controller
→ AWS APIs
→ ALB

---

## 7. Path-Based Routing

Path-based routing sends requests to different Services based on the URL path.

Example:

`https://dojo.example.com/`

→ `frontend-service`

`https://dojo.example.com/api/users`

→ `backend-service`

Conceptually:

Internet
→ ALB
→ `/` → frontend-service
→ `/api/*` → backend-service

This is Layer-7 HTTP routing and is one of the main reasons ALB is suitable for our application.

---

## 8. Host-Based Routing

Traffic can also be routed based on hostname.

Example:

`www.dojo.com` → frontend-service

`api.dojo.com` → backend-service

Path-based and host-based routing can also be combined.

---

## 9. Why ALB for This Project?

Our application is an HTTP/HTTPS web application requiring:

- HTTP/HTTPS
- Path-based routing
- Host-based routing if needed
- TLS termination
- Integration with AWS services

Therefore ALB is a natural fit.

NLB is primarily a Layer-4 networking option for TCP/UDP-oriented workloads and is not the first choice for our HTTP path-routing requirement.

---

## 10. TLS / HTTPS

Because we are using AWS ALB, TLS can be integrated with AWS Certificate Manager (ACM).

Typical architecture:

Route 53
→ domain
→ ALB
→ ACM certificate
→ HTTPS listener
→ Ingress rules
→ Kubernetes Services
→ Pods

TLS can terminate at the ALB, allowing the external connection to be HTTPS.

---

## 11. Service Types in This Architecture

Backend:

`ClusterIP`

Frontend:

`ClusterIP`

The ALB provides the external entry point, so the application Services do not necessarily need to be `LoadBalancer`.

Backend:

Internet
→ ALB
→ backend-service (ClusterIP)
→ backend Pods

Frontend:

Internet
→ ALB
→ frontend-service (ClusterIP)
→ frontend Pods

This avoids unnecessarily exposing the backend through its own external endpoint.

---

## 12. ClusterIP vs NodePort vs LoadBalancer

### ClusterIP

Internal stable Service endpoint.

Used for:

`Frontend → Backend`

or other internal application communication.

### NodePort

Exposes a Service through a port on the worker nodes.

Example:

`NodeIP:30080`

→ Service
→ Pods

NodePort does not automatically mean public access. Network routing, subnet configuration and security groups still determine reachability.

However, it creates an additional node-level entry point, so it is unnecessary for our internal backend.

### LoadBalancer

Requests a cloud load-balancer integration.

Typical flow:

Internet
→ AWS Load Balancer
→ Service
→ Pods

We are using the ALB through the AWS Load Balancer Controller instead of creating separate LoadBalancer Services for frontend/backend.

---

## 13. OIDC for GitHub vs OIDC for EKS

There are two different workload identity scenarios.

### GitHub OIDC

GitHub Actions is a non-human workload.

GitHub
→ OIDC token
→ AWS trusts GitHub identity
→ STS
→ GitHub IAM Role
→ ECR permissions

Purpose:

Allow GitHub Actions to access AWS without storing long-lived AWS access keys.

### EKS OIDC / IRSA

The AWS Load Balancer Controller is also a non-human workload.

Controller Pod
→ Kubernetes ServiceAccount
→ EKS OIDC token
→ AWS trusts the ServiceAccount identity
→ STS
→ Controller IAM Role
→ ALB permissions

This is called:

`IRSA = IAM Roles for Service Accounts`

---

## 14. OIDC vs IAM Permissions

Easy mental model:

OIDC:

"Who are you?"

IAM Role:

"Which identity/permission set are you assuming?"

IAM Policy:

"What are you allowed to do?"

For the ALB Controller:

EKS ServiceAccount
→ OIDC establishes workload identity/trust
→ IAM Role is assumed
→ IAM Policy allows required ALB/AWS API actions

The GitHub IAM role and ALB Controller IAM role should be separate because they represent different workloads with different responsibilities.

---

## 15. ServiceAccount

The ALB Controller runs in a Pod using a Kubernetes ServiceAccount.

Conceptually:

Kubernetes ServiceAccount
→ assigned to ALB Controller Pod
→ associated with IAM Role
→ temporary AWS credentials
→ AWS API access

The ServiceAccount is not the ALB Controller itself. It provides the Kubernetes workload identity used by the Controller.

---

## 16. Complete Control Plane and Data Plane Picture

### Control/Reconciliation Flow

Ingress
→ Kubernetes API
→ AWS Load Balancer Controller
→ EKS OIDC / IRSA
→ IAM Role
→ AWS APIs
→ ALB configuration

### Application Traffic Flow

User
→ Internet
→ ALB
→ Ingress routing rules
→ Frontend/Backend Service
→ Pods
→ Application

The controller primarily handles the first flow; the ALB handles the second flow.

---

## 17. Final Architecture for Our Dojo Project

Internet
→ Route 53 / Domain
→ AWS ALB
→ HTTPS / ACM
→ Ingress rules

Ingress rules:

`/` → frontend-service

`/api/*` → backend-service

Then:

`frontend-service (ClusterIP)`
→ frontend Pods

`backend-service (ClusterIP)`
→ backend Pods

`backend Pods`
→ PostgreSQL RDS

Controller side:

`AWS Load Balancer Controller`
→ watches Ingress
→ uses EKS workload identity / IRSA
→ calls AWS APIs
→ creates and maintains ALB resources

---

## 18. Key Mental Model

Remember these four lines:

`Ingress = WHAT routing do I want?`

`AWS Load Balancer Controller = HOW do I implement that routing in AWS?`

`ALB = WHERE external HTTP/HTTPS traffic is received and routed.`

`Reconciliation = continuously make actual infrastructure match the desired configuration.`

For this project, the final design is:

`Ingress + AWS Load Balancer Controller + AWS ALB + ACM + ClusterIP Services`

This provides external HTTP/HTTPS access while keeping the backend and internal application communication private.