# Kubernetes Namespace & Service Discovery

A **Namespace** is a logical separation inside a Kubernetes cluster. It allows us to organize and isolate Kubernetes resources such as Pods, Deployments, and Services without creating a separate cluster.

Think of a namespace like a **separate workspace or room inside the same Kubernetes cluster**.

    One EKS Cluster
          │
          ├── dev namespace
          │     ├── frontend
          │     └── backend
          │
          └── prod namespace
                ├── frontend
                └── backend

The important point is that a namespace does **not** create separate EC2 nodes or a separate EKS cluster. It is a logical boundary inside the same cluster.

## Why Do We Use Namespaces?

Without namespaces, all applications and resources would live in the same default space.

For a real project, we may have:

    dev
    test
    staging
    prod

Instead of mixing everything together, we can separate them:

    Namespace: dev
        → frontend
        → backend
        → services
        → configmaps
        → secrets

    Namespace: prod
        → frontend
        → backend
        → services
        → configmaps
        → secrets

This makes the cluster easier to organize and manage.

## Real-World Use Case

Suppose our EKS cluster contains both development and production applications:

    EKS Cluster
          │
          ├── dev
          │    ├── frontend
          │    └── backend
          │
          └── prod
               ├── frontend
               └── backend

Both environments may have a Service called:

    backend

But they are different Services because they belong to different namespaces.

    dev/backend
    prod/backend

This allows us to use the same resource names in different environments without conflicts.

## Main Advantages

Namespaces provide:

    1. Organization
       → Keep resources grouped by environment/application/team.

    2. Isolation
       → Separate dev, test and prod resources logically.

    3. Access Control
       → RBAC permissions can be given to specific namespaces.

    4. Resource Control
       → ResourceQuota and LimitRange can control how much
         CPU/memory a namespace can consume.

    5. Easier Management
       → We can list, monitor and manage resources by namespace.

    6. Same Resource Names
       → frontend or backend can exist in multiple namespaces.

## Namespace and Service Discovery

This is where Namespace becomes important for frontend/backend communication.

Suppose we create:

    Namespace: dojo-dev

Inside it:

    frontend Deployment
    frontend Service

    backend Deployment
    backend Service

The backend Service might be:

    backend-service

Kubernetes creates a DNS name for the Service.

Inside the same namespace, the frontend can simply connect using:

    http://backend-service:5000

The frontend does NOT need to know the Pod IP address.

The flow is:

    Frontend Pod
        ↓
    backend-service
        ↓
    Kubernetes DNS
        ↓
    Backend Service
        ↓
    Backend Pod
        ↓
    Backend Container

## Why Do We Need a Service?

Pods are temporary.

A Pod can be deleted and recreated, and its IP address can change.

For example:

    Backend Pod 1
    IP: 10.0.1.10

Later Kubernetes replaces it:

    Backend Pod 2
    IP: 10.0.2.25

If the frontend directly used:

    10.0.1.10

the connection would break.

Instead, we create a Kubernetes Service:

    frontend
        ↓
    backend-service
        ↓
    Backend Pods

The Service provides a stable name and stable virtual endpoint while Kubernetes keeps track of the changing Pod IPs.

## Where Does Namespace Come Into This?

The Service name is associated with its namespace.

For example:

    backend-service
    namespace: dojo-dev

The full Kubernetes DNS name is:

    backend-service.dojo-dev.svc.cluster.local

The parts mean:

    backend-service
        → Service name

    dojo-dev
        → Namespace

    svc
        → Kubernetes Service

    cluster.local
        → Kubernetes cluster DNS domain

So from another namespace, we can explicitly access:

    http://backend-service.dojo-dev.svc.cluster.local:5000

But when frontend and backend are in the **same namespace**, we normally use the short name:

    http://backend-service:5000

Kubernetes automatically searches the current namespace.

## Example for Our EKS Application

We could organize our application like:

    Namespace: dojo-dev

        frontend
            ↓
        frontend-service

        backend
            ↓
        backend-service

The frontend talks to the backend using:

    http://backend-service:5000

The frontend does not need:

    Pod IP
    Node IP
    EKS node name
    AWS IP address

It only needs the Kubernetes Service name.

The complete flow is:

    Frontend Pod
         ↓
    backend-service
         ↓
    Kubernetes DNS
         ↓
    Backend Service
         ↓
    Backend Pod
         ↓
    Flask Application

## What Happens When Backend Pods Scale?

Suppose we initially have:

    backend-service
          ↓
       Pod 1
       Pod 2

Later HPA increases replicas:

    backend-service
          ↓
       Pod 1
       Pod 2
       Pod 3
       Pod 4

The frontend still uses:

    http://backend-service:5000

It does not need to know that new Pods were created.

Kubernetes automatically updates the Service endpoints.

So:

    Frontend
       ↓
    backend-service
       ↓
    ┌──────┬──────┬──────┬──────┐
    ↓      ↓      ↓      ↓
   Pod1   Pod2   Pod3   Pod4

The Service distributes traffic to the available backend Pods.

## Namespace vs Service

These two concepts solve different problems:

    Namespace
        → Organizes and isolates resources.

    Service
        → Provides stable network access to Pods.

They work together:

    Namespace
        ↓
    backend-service
        ↓
    Backend Pods

Namespace tells Kubernetes **which logical environment the Service belongs to**, while the Service provides **the stable endpoint used to reach the Pods**.

## Important Mental Model

Think of a namespace as a **building department** and a Service as a **stable phone number**.

    Namespace
    → Which department/environment?

    Service
    → How do I reach the application?

    Pod
    → The actual application instance

Therefore:

    Namespace
        ↓
    Service
        ↓
    Pods
        ↓
    Containers

## Final Mental Model for Our Project

For our EKS application:

    EKS Cluster
        ↓
    dojo-dev Namespace
        │
        ├── frontend Deployment
        │       ↓
        │   frontend Pods
        │
        ├── frontend Service
        │
        ├── backend Deployment
        │       ↓
        │   backend Pods
        │
        └── backend Service
                ↑
                │
        frontend connects using
        http://backend-service:5000

If we later create `dojo-prod`, we can have another completely separate logical environment:

    dojo-dev
        → frontend
        → backend

    dojo-prod
        → frontend
        → backend

Both can use the same Service names because they are in different namespaces.

**In one sentence: A Namespace logically separates and organizes Kubernetes resources, while a Service provides a stable DNS-based endpoint for communication between Pods; in our application, the frontend can reach the backend using the backend Service name, with the namespace defining which environment that Service belongs to.**