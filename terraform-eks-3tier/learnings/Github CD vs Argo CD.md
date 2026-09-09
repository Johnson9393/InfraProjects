# GitHub Actions CD vs Argo CD — GitOps Fundamentals

## 1. Why Are We Introducing Argo CD?

So far, our application deployment architecture uses:

- GitHub
- GitHub Actions
- Docker
- Amazon ECR
- Amazon EKS
- Kubernetes
- AWS Load Balancer Controller
- ALB
- RDS
- Kubernetes ConfigMaps and Secrets
- GitHub OIDC for secure AWS authentication

GitHub Actions can perform both CI and CD.

However, Argo CD introduces a different deployment model called **GitOps**.

The key difference is:

**GitHub Actions can deploy to Kubernetes.**

**Argo CD continuously reconciles Kubernetes with the desired state stored in Git.**

---

# 2. GitHub Actions — CI

Our current CI flow is:

Developer
→ Push code to GitHub
→ GitHub Actions
→ Build Docker image
→ Push image to ECR

For example:

Developer pushes a backend change.

GitHub Actions builds:

`backend:<commit-sha>`

and pushes it to:

`ECR`

For example:

`dojo-dev-backend:abc123`

At this point, the image is available in ECR.

---

# 3. GitHub Actions Can Also Perform CD

GitHub Actions is not limited to CI.

It can also directly deploy the newly created image to EKS.

The general flow becomes:

Developer
→ GitHub
→ GitHub Actions
→ Build image
→ Push image to ECR
→ Authenticate to AWS
→ Connect to EKS
→ Update Kubernetes Deployment
→ Kubernetes performs the rollout

For example, GitHub Actions could execute:

`aws eks update-kubeconfig`

followed by:

`kubectl set image deployment/backend backend=<ECR_IMAGE>:<GITHUB_SHA> -n dojo`

The exact commands can vary depending on the deployment strategy.

The important concept is:

GitHub Actions directly tells Kubernetes:

"Deploy this image version."

---

# 4. Example — GitHub Actions CI + CD

Suppose a developer pushes a backend change.

The GitHub commit SHA is:

`abc123`

GitHub Actions can:

1. Build the Docker image.
2. Tag it as `backend:abc123`.
3. Push it to ECR.
4. Authenticate to AWS using GitHub OIDC.
5. Authenticate/connect to EKS.
6. Update the backend Deployment to use `backend:abc123`.

The flow becomes:

Developer
→ GitHub
→ GitHub Actions
→ Docker build
→ ECR
→ kubectl
→ EKS
→ Kubernetes Deployment
→ New backend Pods

This is a perfectly valid CI/CD architecture.

---

# 5. What Problem Does GitHub Actions CD Solve?

It automates deployment.

Without automation:

Developer
→ Build image manually
→ Push image manually
→ Connect to cluster
→ Run kubectl manually
→ Update application

With GitHub Actions:

Developer
→ Push code
→ Pipeline automatically builds
→ Pushes image
→ Deploys the new version

Therefore, GitHub Actions CD solves:

- Manual deployment
- Repetitive deployment commands
- Human error
- Slow releases
- Lack of deployment automation

---

# 6. But What Is the Limitation?

Consider this situation.

GitHub Actions deployed:

`backend:abc123`

The deployment is successful.

The GitHub Actions workflow finishes.

Later, someone manually changes the Kubernetes Deployment.

For example:

Git desired state:

`backend:abc123`

Kubernetes live state:

`backend:xyz999`

Now there is a difference between what we intended and what is actually running.

This is called **drift**.

GitHub Actions does not normally continuously watch the Kubernetes cluster after its workflow has completed.

It executed the deployment and finished.

If nobody triggers another workflow, GitHub Actions does not automatically say:

"The live cluster has drifted from the desired state. I need to fix it."

---

# 7. This Is Where GitOps Comes In

GitOps is the idea of using Git as the source of truth for the desired state of the infrastructure/application.

For Kubernetes, this means the desired configuration can live in Git.

For example, Git can define:

- Which image version should run
- Number of replicas
- Kubernetes Deployment configuration
- Services
- Ingress
- ConfigMaps
- Other Kubernetes resources

Git represents:

**What we WANT Kubernetes to look like.**

Kubernetes represents:

**What IS currently running.**

---

# 8. Argo CD — Core Idea

Argo CD is a Kubernetes-native GitOps continuous delivery tool.

Its fundamental job is:

**Continuously compare the desired state in Git with the live state in Kubernetes and reconcile them.**

Mental model:

Git
→ Desired State

Kubernetes
→ Live State

Argo CD
→ Compare and Reconcile

---

# 9. Example of Drift

Suppose Git says:

Backend image:

`backend:abc123`

But Kubernetes currently has:

`backend:xyz999`

Then:

Git desired state
≠
Kubernetes live state

Argo CD detects this difference.

The application can become:

**OutOfSync**

If automated synchronization/self-healing is configured, Argo CD can reconcile the Kubernetes state back toward the desired state defined in Git.

The conceptual flow is:

Git
→ backend:abc123

Kubernetes
→ backend:xyz999

Argo CD
→ Detect difference

Argo CD
→ Reconcile

Kubernetes
→ backend:abc123

---

# 10. GitHub Actions vs Argo CD

The fundamental difference is not:

"GitHub Actions can deploy and Argo CD can deploy."

Both can participate in deployment.

The important difference is the deployment model.

GitHub Actions CD:

GitHub
→ GitHub Actions
→ kubectl
→ Kubernetes

GitHub Actions actively performs the deployment.

Argo CD / GitOps:

Git
→ Argo CD
→ Kubernetes

Argo CD continuously observes and reconciles the desired state.

---

# 11. Important Responsibility Difference

With GitHub Actions CI + CD:

GitHub Actions can be responsible for:

- Testing
- Building images
- Pushing images to ECR
- Deploying the image to Kubernetes

With a GitOps model:

GitHub Actions can remain responsible for:

- Testing
- Building images
- Pushing images to ECR
- Updating the desired Kubernetes configuration in Git

Argo CD becomes responsible for:

- Watching Git
- Comparing desired state with Kubernetes live state
- Detecting drift
- Synchronizing Kubernetes with Git
- Maintaining the desired state

Kubernetes remains responsible for:

- Scheduling Pods
- Running containers
- Rolling out Deployments
- Maintaining replicas
- Service networking
- Other Kubernetes control-plane responsibilities

---

# 12. GitOps Flow for Our Application

The eventual architecture we are working toward is:

Developer
→ Push application code
→ GitHub
→ GitHub Actions
→ Build/Test
→ Docker image
→ ECR

Then the desired Kubernetes configuration is updated in Git.

Git
→ Kubernetes desired state

Argo CD
→ Detects Git change
→ Compares desired state with EKS
→ Synchronizes

EKS
→ Kubernetes Deployment
→ New Pods
→ Service
→ ALB
→ Application

---

# 13. Why Argo CD Is Useful

Argo CD gives us continuous reconciliation.

This provides:

- Git as the source of truth
- Visibility into application synchronization state
- Detection of drift
- Automated synchronization when configured
- Kubernetes-native deployment management
- Git-based deployment history
- A clear separation between CI and CD responsibilities

The key benefit is not simply:

"Argo CD deploys applications."

The deeper benefit is:

**Argo CD continuously ensures that the Kubernetes cluster reflects the desired state defined in Git.**

---

# 14. Important Mental Model

Remember these three concepts:

### GitHub Actions

"Build it and, if configured for CD, deploy it."

### Git

"This is what the system SHOULD look like."

### Argo CD

"Make Kubernetes match what Git says it SHOULD look like."

### Kubernetes

"Actually run and manage the application."

---

# 15. Complete High-Level Architecture

Application CI:

Developer
→ GitHub
→ GitHub Actions
→ Build/Test
→ Docker Image
→ ECR

GitOps CD:

Git
→ Argo CD
→ EKS
→ Kubernetes Deployment
→ Pods
→ Services
→ ALB
→ Users

The overall mental model is:

**GitHub Actions = CI / image delivery**

**Git = desired state**

**Argo CD = continuous reconciliation / GitOps CD**

**EKS = application runtime**

---

# 16. Current Learning Boundary

At this stage, we have only established the fundamentals.

We understand:

- GitHub Actions can perform both CI and CD.
- GitHub Actions can dynamically deploy image tags such as a Git commit SHA.
- GitHub Actions CD solves manual deployment and automation problems.
- GitHub Actions does not normally continuously monitor the cluster after its workflow finishes.
- Manual changes can create drift between Git and Kubernetes.
- Argo CD continuously compares Git desired state with Kubernetes live state.
- Argo CD can detect drift.
- With synchronization/self-healing configured, Argo CD can reconcile the cluster back toward the Git-defined state.
- GitOps treats Git as the source of truth for the desired Kubernetes state.

The next step is to take the existing Argo CD code for this project and understand exactly how these concepts are implemented in practice, line by line.
