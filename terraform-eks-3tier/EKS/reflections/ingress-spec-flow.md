# Kubernetes Ingress — Spec, IngressClass & Routing Rules

## 1. What is `spec`?

`spec` defines the **desired behavior/configuration** of the Kubernetes Ingress.

In simple terms:

    metadata
      ↓
    "What is this object?"

    spec
      ↓
    "What should this Ingress do?"

For our Ingress, `spec` mainly defines:

    spec
    ├── ingressClassName
    └── rules
          └── paths
                └── backend destinations

---

## 2. `ingressClassName`

Example:

    spec:
      ingressClassName: alb

`ingressClassName` tells Kubernetes which **IngressClass/controller** should handle this Ingress.

In our project:

    ingressClassName: alb

means:

    This Ingress
        ↓
    ALB IngressClass
        ↓
    AWS Load Balancer Controller

We installed the AWS Load Balancer Controller earlier using Helm.

The controller watches Ingress resources associated with the `alb` class and uses them to create/configure AWS ALBs.

### Why do we need an IngressClass?

A Kubernetes cluster can have different Ingress controllers.

For example:

    nginx
    traefik
    alb

An IngressClass identifies which controller should handle a particular Ingress.

Conceptually:

    Ingress
       │
       ├── ingressClass: nginx
       │       ↓
       │   NGINX Controller
       │
       ├── ingressClass: traefik
       │       ↓
       │   Traefik Controller
       │
       └── ingressClass: alb
               ↓
          AWS Load Balancer Controller

For our EKS project:

    ingressClassName: alb

because we want the AWS Load Balancer Controller to handle our Ingress and create/configure an AWS ALB.

---

# 3. `rules`

Example:

    spec:
      rules:
        - http:
            paths:
              ...

`rules` define **how incoming application traffic should be routed**.

The Ingress examines the incoming request and determines which rule/path matches.

For our application, the important part is the URL path.

Example:

    https://example.com/
    https://example.com/api/topics

The Ingress uses the path to decide which Kubernetes Service should receive the request.

---

# 4. `http`

Example:

    rules:
      - http:
          paths:

`http` indicates that we are defining HTTP application-layer routing rules.

It does NOT mean that the application can never use HTTPS.

For example, with HTTPS configured:

    Browser
       ↓
    HTTPS :443
       ↓
    ALB
       ↓
    TLS termination
       ↓
    HTTP request/path routing
       ↓
    Kubernetes Service

The ALB can terminate TLS using an ACM certificate and then perform the path-based routing.

Therefore, the same routing concept can be used when users access:

    https://example.com/

or:

    https://example.com/api/topics

HTTPS configuration and path-based routing are separate concerns.

---

# 5. `paths`

Example:

    paths:
      - path: /api
      - path: /

`paths` contains the URL paths that the Ingress should examine.

Our application has two important paths:

    /api
    /

Conceptually:

    Incoming request
          ↓
        Ingress
          ↓
    Check request path
          ↓
    ┌───────────────┐
    │               │
    /api            /
    │               │
    ↓               ↓
    Backend         Frontend

---

# 6. `/api` routing rule

Example:

    - path: /api
      pathType: Prefix
      backend:
        service:
          name: backend-service
          port:
            number: 8080

This means:

"If the request path starts with `/api`, send the request to `backend-service` on port `8080`."

Examples:

    /api
    /api/
    /api/login
    /api/topics
    /api/questions

All can match `/api` because we are using:

    pathType: Prefix

The routing becomes:

    /api/topics
         ↓
    matches /api
         ↓
    backend-service:8080
         ↓
    Backend Pods

---

# 7. `/` routing rule

Example:

    - path: /
      pathType: Prefix
      backend:
        service:
          name: frontend-service
          port:
            number: 80

This means:

"If the request matches `/`, send it to `frontend-service` on port `80`."

Examples:

    /
    /login
    /dashboard
    /students
    /quiz

can match `/`.

The routing becomes:

    /dashboard
         ↓
    matches /
         ↓
    frontend-service:80
         ↓
    Frontend Pods

---

# 8. What does `pathType: Prefix` mean?

Example:

    pathType: Prefix

`Prefix` means the request path is matched based on the beginning of the URL path.

For example:

    /api

matches:

    /api
    /api/
    /api/users
    /api/topics
    /api/quiz

because all of them begin with:

    /api

This is useful for grouping all API endpoints under `/api`.

---

# 9. What does `backend` mean inside an Ingress?

This is an important terminology distinction.

In an Ingress:

    backend

means:

    "The destination where the matching request should be sent."

It does NOT necessarily mean the application's backend application.

For example:

    path: /
      ↓
    backend:
      ↓
    frontend-service

Here the Ingress `backend` is actually the frontend Service.

So:

    Ingress backend = destination

It is different from:

    application backend = backend application

---

# 10. Backend destination → Kubernetes Service

Example:

    backend:
      service:
        name: frontend-service
        port:
          number: 80

This means:

    Matching request
          ↓
    Ingress backend
          ↓
    Kubernetes Service
          ↓
    frontend-service:80
          ↓
    Frontend Pods

For the API:

    Matching request
          ↓
    Ingress backend
          ↓
    Kubernetes Service
          ↓
    backend-service:8080
          ↓
    Backend Pods

The Ingress normally does not directly choose an individual Pod.

It sends traffic to the Kubernetes Service, and the Service handles Pod selection.

---

# 11. Why does `/` go to `frontend-service`?

Because `backend` is simply the destination of the Ingress rule.

Therefore:

    path: /
    backend:
      service:
        name: frontend-service

means:

    Request /
       ↓
    Ingress
       ↓
    Destination = frontend-service
       ↓
    Frontend Pods

The word `backend:` does not mean "application backend."

It means:

    backend = destination for this Ingress rule

---

# 12. More specific path matching

Both `/api` and `/` can technically match a request such as:

    /api/topics

because `/` is also a prefix.

However, the more specific matching path takes precedence.

Therefore:

    /api/topics
         ↓
    matches /api
         ↓
    backend-service

while:

    /dashboard
         ↓
    matches /
         ↓
    frontend-service

So our routing is effectively:

    /api/*
       ↓
    backend-service:8080

    /*
       ↓
    frontend-service:80

---

# 13. Complete routing flow

Our Ingress configuration creates this logical routing:

                    Incoming Request
                           ↓
                          ALB
                           ↓
                        Ingress
                           ↓
                    Check URL path
                           │
                ┌──────────┴──────────┐
                │                     │
             /api/*                   /*
                │                     │
                ↓                     ↓
       backend-service        frontend-service
             :8080                   :80
                │                     │
                ↓                     ↓
         Backend Pods          Frontend Pods

Examples:

    https://example.com/
            ↓
    frontend-service:80

    https://example.com/login
            ↓
    frontend-service:80

    https://example.com/api/topics
            ↓
    backend-service:8080

    https://example.com/api/login
            ↓
    backend-service:8080

---

# 14. How `spec` connects to the ALB Controller

The complete relationship is:

    Kubernetes Ingress
           │
           ├── ingressClassName: alb
           │
           ├── routing rules
           │
           └── backend destinations
                    │
                    ↓
        AWS Load Balancer Controller
                    │
                    ↓
                AWS ALB
                    │
                    ├── /api → backend-service
                    │
                    └── / → frontend-service

The Ingress defines the desired routing behavior.

The AWS Load Balancer Controller watches the Ingress and reconciles the corresponding AWS ALB configuration.

---

# 15. Easy mental model

Remember `spec` like this:

    spec
      ↓
    "What should this Ingress do?"

    ingressClassName
      ↓
    "Which controller should handle me?"
      ↓
    alb → AWS Load Balancer Controller

    rules
      ↓
    "How should traffic be routed?"

    paths
      ↓
    "Which URL path was requested?"

    backend
      ↓
    "Where should the matching request go?"

    service
      ↓
    "Which Kubernetes Service is the destination?"

Therefore:

    /api
      ↓
    backend-service:8080
      ↓
    Backend Pods

    /
      ↓
    frontend-service:80
      ↓
    Frontend Pods