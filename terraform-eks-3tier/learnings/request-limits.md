# Kubernetes Requests & Limits

Kubernetes **requests and limits** control how much CPU and memory a Pod/container needs and how much it is allowed to use. They help Kubernetes place Pods on the right nodes, prevent one application from consuming all node resources, and make resource usage predictable.

A simple mental model is:

    REQUEST = "How much resource does my Pod need to be scheduled?"
    LIMIT   = "What is the maximum resource my container can use?"

Example:

    resources:
      requests:
        cpu: "250m"
        memory: "512Mi"
      limits:
        cpu: "500m"
        memory: "1Gi"

Here, the application requests **250m CPU (0.25 CPU) and 512Mi memory**. Kubernetes uses these values when deciding where the Pod can run. The container can use more when available, but it is allowed to use at most **500m CPU and 1Gi memory**.

## Why Do We Use Requests?

Requests are mainly used by the **Kubernetes Scheduler**.

When a Pod needs to be created, the Scheduler checks the resource requests against the available resources on the nodes.

For example:

    Pod request:
      CPU    = 500m
      Memory = 512Mi

    Scheduler:
      ↓
    Check available node capacity
      ↓
    Enough capacity?
      ↓
    YES → Schedule the Pod
    NO  → Pod remains Pending

The important point is that Kubernetes does not simply look at the total CPU or memory of a node. It considers the resources already requested by the Pods running on that node.

## Use Case 1 — Scaling from 3 Pods to 4 Pods

Suppose our backend application is running with 3 Pods:

    Backend Deployment
          ↓
      Pod 1
      Pod 2
      Pod 3

Each Pod has:

    requests:
      cpu: "500m"
      memory: "512Mi"

Now application traffic increases. An HPA may decide that we need another Pod:

    3 Pods → 4 Pods

Kubernetes creates the 4th Pod, and the Scheduler checks whether any node has enough capacity for:

    500m CPU
    512Mi Memory

If a node has enough available capacity:

    HPA
     ↓
    Create 4th Pod
     ↓
    Scheduler checks request
     ↓
    Enough capacity
     ↓
    Pod scheduled
     ↓
    Container starts

If no node has enough capacity:

    HPA
     ↓
    Create 4th Pod
     ↓
    Scheduler checks request
     ↓
    No suitable node
     ↓
    Pod remains Pending

The existing 3 Pods continue running. Kubernetes does not remove them just because the new Pod cannot be scheduled.

If a cluster autoscaler such as Karpenter or Cluster Autoscaler is configured, it can detect that the Pod is Pending because the cluster does not have enough capacity and can provision another node. Once the new node becomes available, the Scheduler can place the Pod on it.

    Pod Pending
        ↓
    No node has enough capacity
        ↓
    Cluster autoscaler adds capacity
        ↓
    New node available
        ↓
    Scheduler schedules Pod
        ↓
    Pod starts

This is an important relationship:

    HPA
      → decides HOW MANY Pods are needed

    Scheduler
      → decides WHERE the Pod can run

    Cluster Autoscaler / Karpenter
      → provides MORE NODE CAPACITY when required

## Use Case 2 — Application Uses More Resources Than Its Request

Suppose we configure:

    requests:
      cpu: "250m"
      memory: "512Mi"

    limits:
      cpu: "500m"
      memory: "1Gi"

Normally the application uses:

    CPU    → 250m
    Memory → 512Mi

During higher traffic it may use:

    CPU    → 400m
    Memory → 800Mi

This is allowed because the usage is still below the limits.

The request is NOT a hard usage limit.

    Request → Used mainly for scheduling
    Limit   → Maximum container usage

If CPU tries to go beyond the CPU limit:

    CPU limit = 500m
    Application wants = 800m

Kubernetes throttles the container's CPU usage, so the application may become slower.

Memory behaves differently:

    Memory limit = 1Gi
    Application tries to use > 1Gi
          ↓
       OOMKilled
          ↓
    Container may restart

Therefore, memory limits are particularly important because exceeding them can result in the container being killed.

## How Do We Choose Requests and Limits?

We should not blindly choose values.

Start by observing the application's actual resource usage during normal and peak traffic.

For example:

    Normal CPU   → 150m
    Peak CPU     → 400m

    Normal Memory → 300Mi
    Peak Memory   → 600Mi

We could initially choose something like:

    requests:
      cpu: "250m"
      memory: "512Mi"

    limits:
      cpu: "500m"
      memory: "1Gi"

Then observe the application and adjust the values based on real usage.

For our EKS project, the frontend and backend Deployment YAMLs will eventually contain resource requests and limits. The exact numbers should be chosen based on the actual resource behavior of our applications and the capacity of our EKS nodes, rather than copied blindly.

## Why Requests and Limits Matter

Requests and limits give Kubernetes predictable resource management.

    Requests
      ↓
    Help Scheduler place Pods correctly

    Limits
      ↓
    Prevent a container from consuming unlimited resources

    Together
      ↓
    Better resource planning
    Better stability
    Better node utilization
    Safer scaling

## Final Mental Model

    REQUEST
    "Kubernetes, reserve enough capacity for me
     so that you can schedule me."

    LIMIT
    "Container, you can use more when available,
     but don't go beyond this maximum."

The complete relationship is:

    Application needs more capacity
             ↓
    HPA increases Pod replicas
             ↓
    New Pod has resource REQUEST
             ↓
    Scheduler checks node capacity
             ↓
       ┌───────────────┐
       │ Enough space? │
       └───────┬───────┘
           YES │ NO
            ↓  │  ↓
          Pod  │ Pod Pending
         starts│
               ↓
        Cluster Autoscaler /
        Karpenter may add node
               ↓
        Scheduler retries
               ↓
          Pod starts

**In one sentence: Requests tell Kubernetes what a Pod needs in order to be scheduled, while limits define the maximum CPU and memory the container is allowed to consume.**