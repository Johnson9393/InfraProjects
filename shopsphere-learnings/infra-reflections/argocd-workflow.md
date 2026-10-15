# Argo CD — GitOps Continuous Delivery for ShopSphere

## 1. What is Argo CD, and why do we need it?

Imagine our GitHub Actions pipeline successfully builds a new ShopSphere Docker image and pushes it to Amazon ECR. The image is ready, but **who makes sure the correct version is deployed in Kubernetes and stays consistent with what we defined in Git?**

We can use GitHub Actions to deploy the application directly. But as our application grows, with multiple microservices and Dev and Prod environments, we need a reliable way to manage the desired state of our Kubernetes applications.

That's where **Argo CD** comes in.

Argo CD is a GitOps continuous delivery tool for Kubernetes. We store our desired deployment configuration in Git, and Argo CD continuously compares that configuration with what's actually running in the cluster.

For ShopSphere, Git is our source of truth for application deployment configuration.

## 2. Why choose Argo CD over GitHub Actions for CD?

GitHub Actions is excellent for CI: testing the code, building Docker images, scanning them, and pushing them to ECR. It can also perform CD by deploying applications with `kubectl` or Helm.

Argo CD gives us a different approach to managing deployments.

| GitHub Actions CD | Argo CD CD |
|---|---|
| A workflow executes deployment commands. | Argo CD continuously compares Git with the live cluster. |
| Deployment usually happens when a workflow is triggered. | Argo CD keeps checking for configuration drift. |
| We need to implement deployment and reconciliation logic in workflows. | Argo CD provides built-in synchronization and reconciliation. |
| We can write separate deployment jobs for Dev and Prod. | One Argo CD instance can manage multiple applications and clusters. |
| Rollback is implemented through workflow commands or Helm operations. | We can revert the Git configuration to a previous version and sync it. |

**The key advantage:** Argo CD doesn't just deploy an application; it continuously works to keep Kubernetes aligned with the desired configuration stored in Git.

For example, suppose our ShopSphere frontend is running image version `v1`. We update the image tag in Git to `v2`. Argo CD detects the change and deploys `v2` when synchronization is enabled or initiated.

Now suppose someone manually changes the live Deployment back to `v1`. If automated sync and self-healing are enabled, Argo CD detects the difference and restores the Git-defined version, `v2`.

That is the practical value of GitOps.

## 3. How GitHub Actions and Argo CD work together

We don't need to replace GitHub Actions with Argo CD. We can use both for their strengths.

1. A developer pushes application code to GitHub.
2. GitHub Actions runs tests and security scans.
3. The pipeline builds the Docker image and pushes it to Amazon ECR.
4. The pipeline updates the image tag in the GitOps repository.
5. Argo CD detects the configuration change.
6. Argo CD synchronizes the desired state with Kubernetes.
7. Kubernetes performs the rollout and starts the new Pods.

**Important:** Argo CD does not automatically discover every new image tag pushed to ECR. Our pipeline must update the GitOps configuration, or we must use a tool such as Argo CD Image Updater.

## 4. How we implement Argo CD in ShopSphere

We install Argo CD inside our EKS cluster using Terraform and Helm.

### Step 1: Create a dedicated namespace

We create a Kubernetes namespace for Argo CD so its resources are separated from our application workloads.

In our Terraform configuration, we use `kubernetes_namespace_v1` to create the namespace.

### Step 2: Install Argo CD using Helm

We use a `helm_release` resource to install the `argo-cd` Helm chart from the Argo Helm repository.

Our configuration includes:

- The Helm chart version.
- The namespace in which Argo CD is installed.
- `server.service.type = ClusterIP`, so the Argo CD server is reachable internally within the cluster.
- `configs.params.server.insecure = true`, so the Argo CD server accepts HTTP behind an HTTPS-terminating ALB.

This installation creates the Argo CD components required to manage Kubernetes applications.

### Step 3: Expose the Argo CD UI through an Ingress

Installing Argo CD does not automatically make its UI publicly accessible. We create a Kubernetes Ingress resource to expose it through the AWS Load Balancer Controller.

Our Ingress configuration does the following:

- Uses the `alb` Ingress class.
- Sets the ALB scheme to `internet-facing`.
- Configures HTTP on port `80` and HTTPS on port `443`.
- Redirects HTTP traffic to HTTPS.
- Supplies the wildcard ACM certificate ARN.
- Uses the shared ALB group name so Argo CD can share an ALB with other ShopSphere services.
- Routes requests for the Argo CD hostname to the `argocd-server` Kubernetes Service on port `80`.

For example, our hostname could be `argocd.dev.infralabx.space`, provided the wildcard certificate covers that hostname.

The AWS Load Balancer Controller observes the Ingress and creates or updates the corresponding ALB configuration.

### Step 4: Create a Route 53 record

We create a Route 53 alias record pointing the Argo CD hostname to the ALB DNS name.

The flow is:

**Browser → Route 53 DNS → ALB HTTPS listener → Argo CD Ingress rule → `argocd-server` Service → Argo CD UI**

This gives us a hostname through which we can access the Argo CD UI.

## 5. How we manage Dev and Prod

For ShopSphere, we plan to host one Argo CD instance on the Dev/platform cluster and use it to manage both Dev and Prod deployments.

- **Dev:** Argo CD deploys to the Dev cluster.
- **Prod:** Argo CD connects to the Prod cluster and deploys the production configuration.
- **Git repository:** Maintains the desired configuration for each environment.
- **Helm:** Provides a reusable deployment chart with environment-specific values.

We can maintain separate Argo CD Applications for Dev and Prod while reusing the same Helm chart.

This gives us centralized deployment management without requiring a separate Argo CD installation in every environment. We must still configure appropriate access controls and cluster permissions.

For larger enterprises with strict production isolation or availability requirements, separate Argo CD instances may be more appropriate.

## 6. The most important concept to remember

Argo CD follows a simple principle:

**Git defines what should run; Kubernetes represents what is running; Argo CD continuously works to bring them into alignment.**

For ShopSphere, GitHub Actions handles our CI pipeline and image publishing, while Argo CD manages continuous delivery to Kubernetes. Together, they give us a practical GitOps deployment workflow that supports multiple environments and consistent application releases.


# Practical Use case

## 1. Problem Statement

Imagine our GitHub Actions pipeline builds a new ShopSphere image, pushes it to ECR, and deploys it to EKS. Later, someone manually changes the Deployment, or the live configuration no longer matches Git.

Who detects that difference and brings the cluster back to the intended configuration?

With a basic GitHub Actions CD pipeline, we must implement that reconciliation logic ourselves. **Argo CD provides continuous comparison and reconciliation between Git and the live Kubernetes cluster.**

## 2. GitHub Actions CD vs Argo CD

| GitHub Actions CD | Argo CD |
|---|---|
| Runs deployment commands through workflows. | Continuously compares Git with Kubernetes. |
| Deployment happens when a workflow triggers. | Detects configuration differences and can synchronize them. |
| Drift correction requires additional workflow logic. | Supports automated sync and self-healing. |
| We implement deployment steps using Helm or `kubectl`. | We declare the desired state in Git; Argo CD reconciles it. |

We use **GitHub Actions for CI and image publishing**, and **Argo CD for Kubernetes continuous delivery**. They complement each other rather than replace each other.

## 3. Practical Use Case — ShopSphere

Suppose our frontend is running image `v1`.

1. A developer pushes code to GitHub.
2. GitHub Actions tests the code, builds image `v2`, scans it, and pushes it to ECR.
3. The pipeline updates the image tag in our GitOps repository to `v2`.
4. Argo CD detects that Git now declares `v2`, while Kubernetes still runs `v1`.
5. Argo CD synchronizes the configuration, and Kubernetes performs a rolling update.
6. If someone manually changes the Deployment back to `v1`, Argo CD can restore `v2` when automated sync and self-healing are enabled.

**Important:** Argo CD does not automatically discover new ECR image tags. Our pipeline must update Git, or we must use an image-update tool.

## 4. How Argo CD Reconciles the Cluster

Argo CD continuously compares the desired state in Git with the live state in Kubernetes.

- **Git:** Desired configuration — image tag, replicas, Service, Ingress, and other resources.
- **Kubernetes:** Actual running configuration.
- **Argo CD:** Detects differences and synchronizes the cluster when synchronization is requested or automated sync is enabled.

For example, if Git declares `replicas: 3` but the live Deployment has `replicas: 2`, Argo CD detects the difference. With synchronization enabled, it applies the desired configuration; Kubernetes then works to maintain three replicas.

## 5. How We Install Argo CD in ShopSphere

We provision Argo CD through Terraform in `core-infra/k8-services`.

### Step 1 — Create a dedicated namespace

We use `kubernetes_namespace_v1` to create the namespace in which Argo CD will run.

### Step 2 — Install Argo CD using Helm

We use `helm_release` with the `argo-cd` chart from the Argo Helm repository.

Our configuration sets:

- `server.service.type = ClusterIP` — keeps the Argo CD Service internal to the cluster.
- `configs.params.server.insecure = true` — allows HTTP between the ALB and Argo CD when HTTPS terminates at the ALB.

### Step 3 — Create the Argo CD Ingress

Our `kubernetes_ingress_v1` resource configures the AWS Load Balancer Controller to expose the Argo CD UI.

The Ingress specifies:

- An internet-facing ALB with IP targets.
- HTTP on port `80` and HTTPS on port `443`.
- HTTP-to-HTTPS redirection.
- The wildcard ACM certificate ARN.
- The shared ALB group name.
- Host-based routing to the `argocd-server` Service on port `80`.

The AWS Load Balancer Controller creates or updates the ALB configuration from this Ingress.

### Step 4 — Create a Route 53 alias record

We point the Argo CD hostname to the ALB DNS name using a Route 53 alias record.

**Request flow:**

Browser → Route 53 → ALB HTTPS listener → Argo CD Ingress → `argocd-server` Service → Argo CD UI

## 6. How We Manage Dev and Prod

For ShopSphere, we use one Argo CD instance hosted on the Dev/platform cluster to manage applications in both Dev and Prod.

- **Dev:** Argo CD deploys the Dev configuration.
- **Prod:** Argo CD connects to the Prod cluster and deploys the Prod configuration.
- **GitOps repository:** Stores the desired configuration for each environment.
- **Helm chart:** Reuses the same deployment templates with environment-specific values.

We create separate Argo CD Applications for Dev and Prod, with appropriate cluster access and permissions.

This provides centralized management without installing Argo CD separately in every environment. Larger enterprises may use separate instances where production isolation or availability requirements demand it.

## 7. Commands to Verify Argo CD

After connecting `kubectl` to the target EKS cluster:

- Check the Argo CD namespace:

  `kubectl get namespaces`

- Check Argo CD Pods:

  `kubectl get pods -n dev-argocd`

- Check the Argo CD Service:

  `kubectl get svc -n dev-argocd`

- Check the Ingress:

  `kubectl get ingress -n dev-argocd`

Use the actual namespace configured in Terraform if it differs from `dev-argocd`.

## Key Takeaway

**GitHub Actions builds and publishes the application; Argo CD continuously reconciles Kubernetes with the desired configuration stored in Git.**

Together, they provide ShopSphere with automated delivery, consistent environments, drift correction, and a reusable GitOps deployment process.