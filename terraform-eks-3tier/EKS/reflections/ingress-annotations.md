# Kubernetes Ingress — Metadata and ALB Annotations

## 1. What is an Ingress?

A Kubernetes Ingress is a Kubernetes resource used to define how incoming HTTP/HTTPS traffic should be routed to Kubernetes Services.

In our EKS project, the intended flow is:

Internet
   ↓
AWS Application Load Balancer (ALB)
   ↓
Kubernetes Services
   ↓
Pods

For example:

/api → backend-service:8080
/    → frontend-service:80

The Ingress defines the routing requirements.

The AWS Load Balancer Controller watches the Ingress and translates those requirements into AWS ALB configuration.

---

## 2. `apiVersion`

Example:

    apiVersion: networking.k8s.io/v1

`apiVersion` tells Kubernetes which API group and API version should be used to interpret the resource definition.

Ingress belongs to the `networking.k8s.io` API group and we are using its `v1` API version.

The structure is:

    networking.k8s.io
            ↓
        API group

    v1
     ↓
    API version

Therefore:

    apiVersion: networking.k8s.io/v1
    kind: Ingress

means:

"Create an Ingress resource using the `v1` version of the `networking.k8s.io` Kubernetes API."

### Important distinction

`v1` is not simply "the version of the Ingress."

It is the version of the Kubernetes API through which the Ingress resource is defined.

Examples:

    apiVersion: apps/v1
    kind: Deployment

    apiVersion: v1
    kind: Service

    apiVersion: networking.k8s.io/v1
    kind: Ingress

Easy recall:

    apiVersion → Which API definition?
    kind       → Which Kubernetes resource?

---

## 3. `kind`

Example:

    kind: Ingress

`kind` tells Kubernetes what type of resource we are creating.

Here:

    kind: Ingress

means we are creating a Kubernetes Ingress object.

Together:

    apiVersion: networking.k8s.io/v1
    kind: Ingress

means:

"Use the `networking.k8s.io/v1` API definition to create an Ingress."

---

## 4. `metadata`

Example:

    metadata:
      name: devopsdozo-ingress
      namespace: devopsdozo
      annotations:
        ...

`metadata` contains information that identifies and provides additional information/configuration for the Kubernetes object.

Our Ingress metadata contains:

    metadata
    ├── name
    ├── namespace
    └── annotations

---

## 5. `metadata.name`

Example:

    metadata:
      name: devopsdozo-ingress

This gives the Ingress object its name.

The name allows Kubernetes and administrators to distinguish this Ingress from other Ingress objects in the same namespace.

For example:

    kubectl get ingress -n devopsdozo

    kubectl describe ingress devopsdozo-ingress -n devopsdozo

If multiple Ingresses exist:

    devopsdozo-ingress
    admin-ingress
    api-ingress

the name identifies each object.

Easy recall:

    name
      ↓
    Identity/name of this Kubernetes object

---

## 6. `metadata.namespace`

Example:

    metadata:
      namespace: devopsdozo

This places the Ingress inside a specific Kubernetes namespace.

For our project, we will use:

    namespace: dojo

Example:

    EKS Cluster
       │
       ├── dev namespace
       │     └── Ingress
       │
       ├── staging namespace
       │     └── Ingress
       │
       └── prod namespace
             └── Ingress

An Ingress belonging to one namespace is not automatically part of another namespace.

### Important distinction

A Kubernetes namespace is not the same thing as an AWS account.

Namespaces provide Kubernetes-level scope and organization.

For example, one EKS cluster can contain:

    dojo-dev
    dojo-stage
    dojo-prod

Each namespace can have its own Kubernetes resources.

Easy recall:

    namespace
        ↓
    "Which Kubernetes namespace does this object belong to?"

---

# 7. Annotations

Example:

    metadata:
      annotations:
        alb.ingress.kubernetes.io/scheme: "internet-facing"
        alb.ingress.kubernetes.io/target-type: "ip"
        alb.ingress.kubernetes.io/healthcheck-path: "/"

Annotations attach additional information or configuration to a Kubernetes object.

In our project, these particular annotations are understood by the AWS Load Balancer Controller.

The flow is:

    Kubernetes Ingress
            ↓
        Annotations
            ↓
    AWS Load Balancer Controller
            ↓
        AWS ALB

The annotations provide AWS-specific configuration to the controller.

### Important point

Annotations do not create the ALB by themselves.

The AWS Load Balancer Controller reads the annotations and then creates/configures the required AWS resources.

---

# 8. Labels vs Annotations

Labels and annotations are both part of Kubernetes metadata, but they have different purposes.

## Labels

Labels are primarily used to identify, categorize, and select Kubernetes objects.

Example:

    labels:
      app: frontend

A Service can use:

    selector:
      app: frontend

This tells the Service to find Pods with:

    app=frontend

Example:

    Frontend Pod
         │
         └── label: app=frontend
                       ↑
                       │
                 Service selector
                       │
                       ↓
                 Finds the Pod

## Annotations

Annotations are used to attach additional information or configuration to a Kubernetes object.

Example:

    annotations:
      alb.ingress.kubernetes.io/scheme: "internet-facing"

This is not used to select Pods.

Instead, the AWS Load Balancer Controller reads it as configuration for the AWS ALB.

### Easy recall

    LABEL
      ↓
    "What is this / which group does it belong to?"

    ANNOTATION
      ↓
    "What additional information or configuration applies to this object?"

---

# 9. `alb.ingress.kubernetes.io/scheme`

Example:

    alb.ingress.kubernetes.io/scheme: "internet-facing"

This tells the AWS Load Balancer Controller to create an internet-facing Application Load Balancer.

Our application needs to be reachable from a user's browser.

The intended architecture is:

    User Browser
          ↓
       Internet
          ↓
    Internet-facing ALB
          ↓
    Kubernetes Services
          ↓
         Pods

For an internet-facing ALB, the controller selects suitable public subnets for the load balancer.

Our VPC has:

    Public Subnets
         ↓
    Internet-facing ALB

    Private Subnets
         ↓
    Application Pods

This allows the ALB to be publicly reachable while our application workloads can remain in private subnets/networking.

### Easy recall

    internet-facing
          ↓
    Public-facing ALB

---

# 10. `alb.ingress.kubernetes.io/target-type`

Example:

    alb.ingress.kubernetes.io/target-type: "ip"

This determines what the ALB Target Group registers as its targets.

AWS ALB supports target types including:

    instance
    ip
    lambda

---

## 10.1 `instance`

Example:

    target-type = instance

The ALB Target Group registers EC2 instances.

In an EKS environment, this can mean targeting the worker nodes.

Conceptually:

    ALB
     ↓
    EC2 Worker Node
     ↓
    Kubernetes networking
     ↓
    Pod

The ALB is targeting the EC2 worker nodes rather than directly registering Pod IPs.

---

## 10.2 `ip`

Example:

    target-type = ip

The ALB Target Group registers IP addresses.

For our EKS setup, these are the Kubernetes Pod IPs.

Example:

    Frontend Pod 1 → 10.0.3.181
    Frontend Pod 2 → 10.0.4.46

The ALB Target Group can contain:

    10.0.3.181:80
    10.0.4.46:80

Traffic can therefore flow:

    ALB
     ↓
    Pod IP
     ↓
    Frontend Pod

For the backend:

    ALB
     ↓
    Backend Pod IP
     ↓
    Backend Pod

This is the target type we are using for our EKS application.

---

## 10.3 `lambda`

Example:

    target-type = lambda

The ALB Target Group can target an AWS Lambda function.

Conceptually:

    Internet
       ↓
      ALB
       ↓
     Lambda

This is useful for serverless applications and is not what we need for our Kubernetes Pods.

---

## 10.4 Easy target-type recall

    instance
        ↓
    EC2 instance/node

    ip
        ↓
    IP address
        ↓
    Kubernetes Pod IPs in our setup

    lambda
        ↓
    Lambda function

---

# 11. Why are we using `target-type: ip`?

Our application runs inside Kubernetes Pods.

For example:

    Frontend Pod 1 → 10.0.3.181
    Frontend Pod 2 → 10.0.4.46

With IP target mode:

    ALB
     ↓
    Target Group
     ↓
    Pod IP
     ↓
    Pod

The ALB Target Group represents the application Pods directly instead of using the EC2 worker nodes as the registered targets.

This is a natural model for our EKS application because our actual application workloads are Pods.

---

# 12. Pod IPs are ephemeral

Kubernetes Pods are ephemeral.

A Pod can be deleted and replaced, and the replacement Pod can receive a different IP address.

Example:

    BEFORE

    Frontend Pod A → 10.0.3.181
    Frontend Pod B → 10.0.4.46

The ALB Target Group contains:

    10.0.3.181
    10.0.4.46

Now Pod A is terminated.

Kubernetes creates a replacement:

    OLD
    10.0.3.181 → Pod removed

    NEW
    10.0.3.200 → Replacement Pod

The new Pod has a different IP.

---

# 13. How does the ALB handle changing Pod IPs?

This is where the AWS Load Balancer Controller becomes important.

The controller is continuously running and watches Kubernetes resources.

Conceptually:

    Kubernetes API
          ↑
          │
       watches
          │
    ALB Controller
          │
          │ reconciliation
          ↓
       AWS ALB

When the Pods change, the controller notices the change and updates the AWS ALB Target Groups.

For example:

    OLD TARGET

    10.0.3.181

    ↓

    Pod removed

    ↓

    Controller reconciles

    ↓

    REMOVE 10.0.3.181

    ADD 10.0.3.200

    ↓

    NEW TARGET

    10.0.3.200

The same mechanism works when the number of replicas changes.

Example:

    replicas = 2

    Pod 1 → IP 1
    Pod 2 → IP 2

After scaling:

    replicas = 4

    Pod 1 → IP 1
    Pod 2 → IP 2
    Pod 3 → IP 3
    Pod 4 → IP 4

The controller updates the ALB Target Group to reflect the current application Pods.

### Key concept

    Pods are dynamic
          ↓
    Pod IPs can change
          ↓
    Controller watches Kubernetes
          ↓
    Controller reconciles AWS ALB
          ↓
    ALB targets remain synchronized

---

# 14. `alb.ingress.kubernetes.io/healthcheck-path`

Example:

    alb.ingress.kubernetes.io/healthcheck-path: "/"

This tells the ALB which HTTP path to use when performing health checks against its targets.

Conceptually:

    ALB
     │
     │ GET /
     ↓
    Target
     │
     ↓
    HTTP response

The ALB continuously performs health checks.

For example:

    Target 1 → Healthy
    Target 2 → Healthy
    Target 3 → Unhealthy

The ALB can send normal traffic to healthy targets and avoid sending normal traffic to an unhealthy target.

### Important distinction

The ALB does not normally wait for a health check after every user request.

Instead:

    ALB
     │
     ├── continuously checks Target 1
     ├── continuously checks Target 2
     └── continuously checks Target 3

It maintains the health status of the targets and uses that information when deciding where normal traffic can be sent.

---

# 15. Complete meaning of our three annotations

Our configuration:

    annotations:
      alb.ingress.kubernetes.io/scheme: "internet-facing"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/healthcheck-path: "/"

Can be read as:

    scheme
      ↓
    Make the ALB Internet-facing

    target-type: ip
      ↓
    Register Pod IPs as ALB targets

    healthcheck-path: /
      ↓
    Use "/" for ALB target health checks

---

# 16. How the Ingress and ALB Controller work together

The Ingress does not directly create the ALB.

The flow is:

    Terraform / kubectl
            ↓
    Creates Kubernetes Ingress
            ↓
    AWS Load Balancer Controller
            ↓
    Reads Ingress configuration
            ↓
    Creates/configures AWS ALB
            ↓
    Creates/configures Target Groups
            ↓
    Registers current Pod IPs
            ↓
    Continuously reconciles changes

The controller therefore acts as the bridge between:

    Kubernetes
        ↕
    AWS Load Balancer

---

# 17. Complete mental model so far

    apiVersion
        ↓
    Which Kubernetes API definition should be used?

    kind
        ↓
    What Kubernetes resource are we creating?

    metadata
        ↓
    Information about the resource

    name
        ↓
    Identifies the Ingress object

    namespace
        ↓
    Places the Ingress inside a specific Kubernetes namespace

    annotations
        ↓
    Additional configuration understood by the
    AWS Load Balancer Controller

    scheme: internet-facing
        ↓
    Public-facing ALB

    target-type: ip
        ↓
    ALB targets Pod IPs

    healthcheck-path: /
        ↓
    ALB continuously checks target health

    AWS Load Balancer Controller
        ↓
    Watches Kubernetes
        ↓
    Reconciles AWS resources
        ↓
    Keeps ALB configuration and Pod targets synchronized

---

# 18. The most important distinction

Remember the responsibilities:

    Ingress
        ↓
    "Here are my traffic-routing requirements."

    Annotations
        ↓
    "Here are additional AWS-specific configuration requirements."

    AWS Load Balancer Controller
        ↓
    "I will translate those requirements into AWS resources."

    AWS ALB
        ↓
    "I will receive and route the actual traffic."

Therefore:

    Ingress ≠ ALB

    Ingress
        ↓
    Kubernetes configuration

    ALB Controller
        ↓
    Kubernetes-to-AWS bridge

    ALB
        ↓
    Actual AWS load balancer receiving traffic