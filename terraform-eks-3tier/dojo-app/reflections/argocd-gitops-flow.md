# Argo CD GitOps Application Flow

## 1. Big Picture

The complete flow is:

Developer
    ↓
GitHub
    ↓
GitHub Actions
    ↓
Build/Test Docker Images
    ↓
Push Images to ECR
    ↓
Kubernetes manifests in Git are updated
    ↓
Argo CD detects the Git change
    ↓
Argo CD syncs the desired state
    ↓
EKS Kubernetes API
    ↓
Deployment
    ↓
Pods
    ↓
Service
    ↓
EndpointSlice
    ↓
ALB / Ingress
    ↓
Users

The important separation is:

- GitHub Actions handles CI and image building.
- Git stores the desired Kubernetes state.
- Argo CD handles continuous deployment and reconciliation.
- EKS/Kubernetes runs the actual application.

---

# 2. Where Argo CD Is Installed

Argo CD itself is installed inside the EKS cluster.

Terraform uses the Kubernetes and Helm providers to communicate with the EKS cluster.

The provider configuration determines WHERE Terraform is connected.

Conceptually:

AWS data source
    ↓
Gets EKS cluster endpoint and certificate
    ↓
Kubernetes provider / Helm provider
    ↓
Connects to EKS
    ↓
Terraform creates Kubernetes resources

Therefore, when ArgoCD.tf creates:

- `argocd` namespace
- Argo CD Helm release
- Argo CD Ingress

they are created inside the EKS cluster that the providers are connected to.

The resource definitions describe WHAT to create.

The providers determine WHERE to create it.

---

# 3. Argo CD Namespace

Terraform first creates a dedicated namespace:

`argocd`

This gives Argo CD its own Kubernetes namespace.

The namespace is separate from:

- `kube-system` → Kubernetes/system components
- `dojo` → application workloads

The important idea is:

Argo CD itself runs inside the EKS cluster, inside the `argocd` namespace.

---

# 4. Installing Argo CD Using Helm

Terraform then uses:

`helm_release`

to install the Argo CD Helm chart.

The important configuration is:

- Helm repository → Argo CD Helm repository
- Chart → `argo-cd`
- Version → pinned chart version
- Namespace → `argocd`

The Helm chart is a package containing the Kubernetes resource definitions needed to install Argo CD.

So the flow is:

Terraform
    ↓
Helm provider
    ↓
Argo CD Helm chart
    ↓
Kubernetes resources
    ↓
argocd namespace
    ↓
Argo CD components running in EKS

---

# 5. Argo CD Server Service

The Helm configuration sets:

`server.service.type = ClusterIP`

This means the Argo CD server is exposed through an internal Kubernetes Service.

It is not directly exposed as a public AWS Load Balancer.

Instead:

Browser
    ↓
HTTPS
    ↓
AWS ALB
    ↓
Kubernetes Ingress
    ↓
argocd-server Service
    ↓
Argo CD Pod

The ALB is therefore the public entry point.

---

# 6. TLS / HTTPS Architecture

The Argo CD Ingress configures the ALB to listen on:

- HTTP 80
- HTTPS 443

The HTTPS listener uses an ACM certificate.

The architecture is:

Browser
    ↓
HTTPS / TLS
    ↓
ALB
    ↓
TLS termination
    ↓
HTTP
    ↓
Argo CD Service
    ↓
Argo CD Pod

The ALB handles the public TLS connection.

Argo CD is configured with:

`server.insecure = true`

because Argo CD receives HTTP traffic behind the ALB after TLS termination.

This does NOT mean the public connection is HTTP.

The public connection remains:

Browser → HTTPS → ALB

---

# 7. Argo CD Ingress

The Terraform Ingress resource creates an ALB-backed Kubernetes Ingress.

Important configuration:

- `ingress_class_name = "alb"`
- `scheme = "internet-facing"`
- `target-type = "ip"`
- HTTPS listener
- ACM certificate
- SSL redirect
- Argo CD server as the backend

The AWS Load Balancer Controller watches the Ingress and creates/configures the AWS ALB.

The flow is:

Terraform
    ↓
Kubernetes Ingress
    ↓
AWS Load Balancer Controller
    ↓
AWS ALB

---

# 8. ACM and Route 53

Terraform also creates the TLS certificate using ACM.

The certificate is created for the Argo CD subdomain.

Route 53 is used for:

1. ACM DNS validation
2. The actual Argo CD DNS record

The final DNS flow is:

User enters Argo CD domain
    ↓
Route 53
    ↓
ALB DNS name
    ↓
AWS ALB
    ↓
Argo CD Ingress
    ↓
Argo CD server

---

# 9. Argo CD Application

Once Argo CD itself is running, Terraform creates an Argo CD Application:

`argocd_application`

This is very important.

The Argo CD Application is NOT the application itself.

It is a configuration object that tells Argo CD:

- What Git repository to watch
- Which branch/revision to use
- Which folder contains the Kubernetes configuration
- Which Kubernetes cluster to deploy to
- How synchronization should behave

Think of it as:

"Argo CD, manage this application using this Git repository and deploy it according to these rules."

---

# 10. Application Metadata

The Application has:

`name = "devopsdozo"`

This is the name of the Argo CD Application object.

It appears as an application inside the Argo CD UI.

The Application object itself is stored in:

`argocd` namespace

This does NOT mean the application's Pods run in the `argocd` namespace.

It only means the Argo CD Application resource belongs to that namespace.

---

# 11. Argo CD Project

The Application uses:

`project = "default"`

An Argo CD Project is an Argo CD organizational and security boundary.

It controls things such as:

- Which repositories an application can use
- Which clusters it can deploy to
- Which namespaces it can use
- Which Kubernetes resources it is allowed to manage

`default` is the built-in Argo CD Project.

It is NOT the same thing as the application's Kubernetes namespace.

---

# 12. Application Destination

The Application contains:

`destination.server = "https://kubernetes.default.svc"`

This tells Argo CD which Kubernetes cluster it should deploy to.

`kubernetes.default.svc` is the internal Kubernetes API Service address available from inside the cluster.

Because Argo CD is running inside this EKS cluster, this points Argo CD to the same EKS cluster.

The flow is:

Argo CD
    ↓
Kubernetes API
    ↓
Same EKS cluster
    ↓
Application resources

Important distinction:

Terraform's Kubernetes provider determines which cluster Terraform talks to.

The Argo CD Application's `destination.server` determines which cluster Argo CD deploys the Git-defined application to.

In this project, both ultimately point to the same EKS cluster.

---

# 13. Application Source

The Application then defines:

`source`

This tells Argo CD where the desired Kubernetes configuration comes from.

The source contains three important pieces:

- `repo_url`
- `path`
- `target_revision`

Together they mean:

"Go to this Git repository, use this branch, and look inside this folder."

---

# 14. Git Repository

The `repo_url` points to the GitHub repository.

This repository contains the Kubernetes configuration that represents the desired state of the application.

Git therefore becomes the source of truth for the Kubernetes deployment configuration.

The important mental model is:

Git
    ↓
Desired state

EKS
    ↓
Live state

Argo CD
    ↓
Compares desired state with live state

---

# 15. Git Path

The `path` specifies the directory inside the repository that Argo CD should use.

For this application:

`Kubernetes-world/3-tier-app/k8s`

So Argo CD does not simply use the entire repository.

It goes to:

Repository
    ↓
Kubernetes-world
    ↓
3-tier-app
    ↓
k8s

The Kubernetes configuration inside that directory becomes the desired state that Argo CD manages.

---

# 16. Git Revision

The Application uses:

`target_revision = "main"`

This tells Argo CD to use the `main` branch.

Therefore:

Repository
    ↓
main branch
    ↓
Kubernetes-world/3-tier-app/k8s
    ↓
Desired Kubernetes configuration

---

# 17. Complete Argo CD Source Connection

The complete source configuration can be understood as:

GitHub repository
    ↓
main branch
    ↓
Kubernetes-world/3-tier-app/k8s
    ↓
Kubernetes manifests
    ↓
Argo CD

This is the GitOps source of truth.

---

# 18. Automated Synchronization

The Application enables:

`sync_policy`

with:

`automated`

This tells Argo CD to automatically synchronize the live Kubernetes cluster with the desired state stored in Git.

Without automated synchronization:

Git changes
    ↓
Argo CD detects difference
    ↓
Application becomes OutOfSync
    ↓
Manual sync can be required

With automated synchronization:

Git changes
    ↓
Argo CD detects difference
    ↓
Argo CD automatically syncs
    ↓
EKS is updated

---

# 19. Prune

The configuration uses:

`prune = true`

Pruning handles resources that are removed from Git.

Example:

Git originally contains:

- Deployment
- Service
- ConfigMap

Later the Service manifest is removed from Git.

Argo CD sees:

Git desired state
    ↓
Deployment
ConfigMap

Live EKS state
    ↓
Deployment
Service
ConfigMap

The Service is no longer part of the desired state.

With pruning enabled, Argo CD removes that Service from the cluster.

Therefore:

`prune = true`

means:

"If a resource is removed from Git, remove the corresponding resource from Kubernetes."

---

# 20. Self-Healing

The configuration also uses:

`self_heal = true`

This handles live-state drift.

Example:

Git says:

backend image = version A

Someone manually changes the Deployment in Kubernetes:

backend image = version B

Now:

Git desired state ≠ EKS live state

Argo CD detects this difference.

With self-healing enabled:

Argo CD
    ↓
Detects drift
    ↓
Reconciles Kubernetes
    ↓
Restores the Git-defined state

Therefore:

`self_heal = true`

means:

"If someone changes the live Kubernetes state manually, bring it back toward the state defined in Git."

---

# 21. Desired State vs Live State

This is the most important Argo CD concept.

Git contains:

DESIRED STATE

EKS contains:

LIVE STATE

Argo CD continuously compares them.

Example:

Git:

backend image = abc123

EKS:

backend image = abc123

Result:

Synced

If someone changes EKS:

Git:

backend image = abc123

EKS:

backend image = xyz999

Result:

OutOfSync

With automated sync and self-healing enabled, Argo CD works to reconcile the cluster back to the Git-defined state.

---

# 22. Complete GitOps Workflow

The complete application workflow is:

Developer
    ↓
Pushes code to GitHub
    ↓
GitHub Actions
    ↓
Runs tests/build
    ↓
Builds Docker images
    ↓
Pushes images to Amazon ECR
    ↓
Kubernetes deployment configuration is updated in Git
    ↓
Argo CD detects Git change
    ↓
Argo CD compares desired state with live state
    ↓
Automated sync
    ↓
Kubernetes API
    ↓
EKS Deployment updated
    ↓
New Pods created
    ↓
Old Pods rolled out
    ↓
Pods become Ready
    ↓
Service selects Pods
    ↓
EndpointSlices contain Pod destinations
    ↓
Ingress / ALB routes traffic
    ↓
Users access the application

---

# 23. CI vs CD Responsibility

The responsibilities are intentionally separated.

GitHub Actions:

- Source code validation
- Testing
- Docker image build
- Docker image push
- Updating deployment configuration when required

Amazon ECR:

- Stores container images

Git:

- Stores desired Kubernetes deployment configuration
- Acts as the source of truth

Argo CD:

- Watches Git
- Detects changes
- Compares Git with the cluster
- Synchronizes changes
- Prunes removed resources
- Self-heals live drift

EKS/Kubernetes:

- Runs the workloads
- Creates Pods
- Performs Deployments/rollouts
- Provides Services
- Maintains EndpointSlices

AWS ALB:

- Receives external traffic
- Handles HTTPS/TLS termination
- Routes traffic to Kubernetes targets

Route 53:

- Provides DNS resolution for the application domain

ACM:

- Provides the TLS certificate used by the ALB

---

# 24. The Complete Architecture

The entire system can be mentally visualized as:

                    DEVELOPER
                        │
                        ▼
                     GitHub
                        │
                        ▼
                 GitHub Actions
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
        Docker Build          Git desired state
             │                     │
             ▼                     ▼
            ECR                  GitHub
                                   │
                                   ▼
                               Argo CD
                                   │
                         Compare Git vs EKS
                                   │
                          Automated Sync
                                   │
                                   ▼
                           Kubernetes API
                                   │
                                   ▼
                                EKS
                                   │
                         ┌─────────┴─────────┐
                         ▼                   ▼
                    Deployments          Services
                         │                   │
                         ▼                   ▼
                       Pods             EndpointSlices
                                             │
                                             ▼
                                           ALB
                                             │
                                             ▼
                                           Users

---

# 25. The Most Important Mental Model

Remember these four layers:

## Layer 1 — Terraform

Terraform creates the infrastructure and platform components.

Examples:

- EKS
- VPC
- IAM
- Argo CD
- Ingress
- ACM
- Route 53
- Kubernetes resources

## Layer 2 — Git

Git contains the desired Kubernetes state.

Git says:

"This is how my application SHOULD look."

## Layer 3 — Argo CD

Argo CD continuously compares:

Git desired state

against:

EKS live state

and reconciles them according to the sync policy.

## Layer 4 — Kubernetes

Kubernetes actually runs the application.

It manages:

- Deployments
- Pods
- Services
- EndpointSlices
- Ingress

---

# 26. One-Line Mental Model

The entire Argo CD implementation can be remembered as:

Terraform installs Argo CD in EKS → Argo CD watches Kubernetes manifests in Git → Argo CD compares Git with EKS → Argo CD automatically reconciles EKS to the Git-defined desired state.

That is the core of GitOps.