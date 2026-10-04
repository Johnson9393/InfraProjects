# ShopSphere — API Gateway Practical Guide

## 1. What Is an API Gateway?

An API Gateway is the **single entry point for client API traffic**.

Instead of exposing every microservice directly:

```text
Client
 ├── Product Service
 ├── User Service
 ├── Cart Service
 ├── Order Service
 └── Payment Service
```

the client communicates with:

```text
Client
   ↓
API Gateway
   ↓
Microservices
```

In ShopSphere, Nginx is currently being used as the API Gateway.

---

## 2. What Problem Does an API Gateway Solve?

Without a gateway, the frontend needs to know every service:

```text
Frontend
 ├── product-service:8001
 ├── user-service:8002
 ├── cart-service:8003
 ├── order-service:8004
 └── payment-service:8005
```

This exposes internal service details to the client and makes the frontend responsible for service routing.

With the gateway:

```text
Frontend
      ↓
   /api/products
      ↓
API Gateway
      ↓
product-service:8001
```

The frontend only knows the gateway.

---

# 3. ShopSphere API Gateway

Current architecture:

```text
Browser
   ↓
localhost:8080
   ↓
API Gateway (Nginx :80)
   │
   ├── /api/products → product-service:8001
   ├── /api/users    → user-service:8002
   ├── /api/cart     → cart-service:8003
   ├── /api/orders   → order-service:8004
   └── /api/payments → payment-service:8005
```

The gateway performs routing and common HTTP handling before traffic reaches the services.

---

# 4. API Gateway Routing

Example:

```text
GET /api/products
```

The gateway can route it to:

```text
product-service:8001
```

Another request:

```text
POST /api/orders
```

can be routed to:

```text
order-service:8004
```

The client does not need to know the internal service address.

---

# 5. Advantages of an API Gateway

The gateway provides a central place for common API concerns.

Typical responsibilities include:

* Routing
* Authentication
* Authorization
* Rate limiting
* Request transformation
* Response transformation
* CORS handling
* TLS termination
* Request validation
* Logging
* Metrics
* Request/trace ID propagation
* Load balancing
* Security policies

Not every gateway must implement all of these. The exact responsibilities depend on the architecture.

---

# 6. Authentication

Authentication answers:

> **Who are you?**

Example:

```text
User
 ↓
POST /login
 ↓
User Service
 ↓
JWT issued
```

The client then sends:

```text
Authorization: Bearer <JWT>
```

for subsequent requests.

The gateway can validate the JWT before forwarding the request.

```text
Client
  ↓
JWT
  ↓
API Gateway
  ↓
Valid?
 ├── No  → 401
 └── Yes → Microservice
```

This prevents obviously unauthenticated requests from reaching internal services.

---

# 7. Authorization

Authorization answers:

> **Are you allowed to perform this operation?**

Example:

```text
GET /api/products
```

may be available to normal users.

But:

```text
DELETE /api/products/123
```

may require an administrator role.

Conceptually:

```text
JWT
 ↓
role = admin
 ↓
Gateway authorization policy
 ↓
Allow / Deny
```

Authentication and authorization are related but different:

```text
Authentication → Who are you?
Authorization  → What are you allowed to do?
```

---

# 8. JWT Practical Example

Suppose a user logs in:

```text
POST /api/users/login
```

User Service authenticates the user and issues a JWT.

Later:

```text
GET /api/orders
Authorization: Bearer <JWT>
```

The gateway can validate the token.

If valid:

```text
Gateway → Order Service
```

If invalid/expired:

```text
Gateway → 401 Unauthorized
```

For production, JWT secrets should be stored securely rather than hardcoded in configuration.

---

# 9. Rate Limiting

Rate limiting controls how many requests a client can make within a period.

Example:

```text
Client
   ↓
API Gateway
   ↓
100 requests/minute allowed
```

If the client exceeds the limit:

```text
101st request
      ↓
429 Too Many Requests
```

This protects downstream services from:

* Accidental traffic spikes
* Abusive clients
* Simple request floods
* Excessive API consumption

Example policy:

```text
/login → stricter limit
/products → higher limit
/orders → controlled limit
```

Rate limiting is normally implemented at the gateway or another dedicated edge layer.

---

# 10. Request Transformation

The gateway can modify a request before forwarding it.

Example:

```text
Client sends:

/api/products/123
```

Gateway transforms/routes it to:

```text
/products/123
```

before sending it to Product Service.

It can also add/remove headers or modify other request information depending on the gateway technology.

---

# 11. Response Transformation

The gateway can also modify the response returned by a service.

Example:

```text
Product Service
      ↓
Internal response
      ↓
API Gateway
      ↓
Client-friendly response
```

This can be useful when the external API contract should differ from the internal service contract.

Transformation should be used carefully because putting too much business logic into the gateway makes it difficult to maintain.

---

# 12. CORS

Browsers enforce cross-origin rules.

The gateway can provide centralized CORS configuration.

Example:

```text
Frontend
https://shopsphere.com

       ↓

API Gateway
https://api.shopsphere.com
```

The gateway can return the appropriate CORS headers so browser requests are permitted according to the configured policy.

---

# 13. TLS / HTTPS

A common production architecture is:

```text
Client
  ↓ HTTPS
API Gateway / Load Balancer
  ↓ HTTP or HTTPS
Microservices
```

TLS can terminate at the edge.

For example:

```text
https://api.shopsphere.com
```

is decrypted at the edge before the request is forwarded internally.

Whether traffic is also encrypted between internal components depends on the security requirements.

---

# 14. API Gateway vs ALB

These are not the same thing.

## ALB

AWS Application Load Balancer primarily provides:

* Layer-7 HTTP/HTTPS load balancing
* Host/path-based routing
* Target health checks
* High availability
* Integration with AWS services
* TLS termination

Example:

```text
Internet
   ↓
ALB
   ↓
EKS Service
   ↓
Pods
```

ALB's primary job is **getting traffic to the appropriate backend targets**.

---

# 15. API Gateway

An API Gateway is more focused on **API management and API-level policies**.

Typical capabilities include:

```text
Authentication
Authorization
Rate limiting
API policies
Request/response transformation
API lifecycle management
API keys
Usage plans
```

Example:

```text
Internet
   ↓
API Gateway
   ↓
Order Service
```

---

# 16. Why Use ALB + API Gateway Together?

They can solve different problems.

A common architecture can be:

```text
Internet
    ↓
ALB
    ↓
Ingress / Gateway entry
    ↓
API Gateway
    ↓
Microservices
```

Conceptually:

```text
ALB
 ↓
"Where should this traffic go?"

API Gateway
 ↓
"Is this API request allowed and how should it be handled?"

Microservices
 ↓
"Perform the business operation."
```

However, this does **not** mean ALB + API Gateway is automatically better.

If the application doesn't need the additional API-management capabilities, adding another layer can introduce unnecessary complexity.

---

# 17. When to Use ALB

Use an ALB when the main requirement is:

```text
Internet traffic
      ↓
Load balancing
      ↓
Application targets
```

For example:

```text
shopsphere.com
      ↓
AWS ALB
      ↓
Frontend / EKS targets
```

ALB is a natural AWS-native choice when you primarily need HTTP/HTTPS load balancing and routing.

---

# 18. When to Use an API Gateway

Use an API Gateway when you need stronger API-management capabilities.

For example:

```text
Mobile App
Web App
External Clients
      ↓
API Gateway
      ↓
Internal APIs
```

Useful when you need centralized:

* Authentication
* Authorization
* Rate limiting
* API policies
* API keys
* Usage controls
* Request/response policies

---

# 19. When to Use Ingress

In Kubernetes, **Ingress is the Kubernetes API object that describes external HTTP/HTTPS routing rules into the cluster**.

Example:

```text
Internet
   ↓
Ingress
   ↓
Service
   ↓
Pods
```

Example rule:

```text
/api/products
      ↓
product-service

/api/orders
      ↓
order-service
```

Ingress itself is normally not the component that performs the actual traffic handling.

An **Ingress Controller** implements those rules.

For example:

```text
Ingress resource
       ↓
AWS Load Balancer Controller
       ↓
AWS ALB
```

So in EKS:

```text
Ingress
   ↓
AWS Load Balancer Controller
   ↓
ALB
```

---

# 20. Ingress vs ALB

They operate at different levels.

```text
Ingress
→ Kubernetes configuration/routing object

ALB
→ Actual AWS load-balancing infrastructure
```

For example:

```text
Ingress rule:

/api
   ↓
shopsphere-service
```

The AWS Load Balancer Controller can translate that Kubernetes configuration into AWS ALB configuration.

---

# 21. Practical EKS Architecture

A possible ShopSphere architecture is:

```text
                    Internet
                       │
                       ▼
                      ALB
                       │
                       ▼
                  Ingress Rules
                       │
                       ▼
                 API Gateway
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     Product        Order         User
      Service       Service       Service
          │            │
          ▼            ▼
      PostgreSQL    PostgreSQL
```

Here each layer has a different responsibility:

```text
ALB
→ external traffic entry + load balancing

Ingress
→ Kubernetes routing declaration

API Gateway
→ API-level policies and gateway functions

Microservices
→ business logic

Databases
→ persistent application data
```

This is an architectural option, not a mandatory stack.

---

# 22. API Gateway vs Ingress vs ALB

| Component   | Main responsibility                          | Example                          |
| ----------- | -------------------------------------------- | -------------------------------- |
| ALB         | Load balancing / HTTP routing                | `/api → EKS target`              |
| Ingress     | Kubernetes routing configuration             | `/api/orders → order-service`    |
| API Gateway | API management and policies                  | JWT, rate limiting, API policies |
| Service     | Internal Kubernetes discovery/load balancing | `order-service:8004`             |

The important point is that **Ingress and API Gateway are not interchangeable concepts**, even though both can perform routing.

---

# 23. Practical Design Decision

For ShopSphere, think about the requirement first.

### Simple application

```text
Internet
   ↓
ALB
   ↓
EKS Services
```

Use this when basic HTTP routing/load balancing is sufficient.

### API-management requirement

```text
Internet
   ↓
API Gateway
   ↓
EKS Services
```

Use this when centralized API policies are important.

### Larger enterprise architecture

```text
Internet
   ↓
ALB / Edge
   ↓
Ingress
   ↓
API Gateway
   ↓
Microservices
```

Use multiple layers only when each layer has a meaningful responsibility.

---

# 24. Key Interview Mental Model

Remember:

```text
ALB
→ "Where should this HTTP traffic go?"

Ingress
→ "What routing should Kubernetes configure?"

API Gateway
→ "How should API traffic be governed and managed?"

Microservice
→ "What business operation should be performed?"
```

Example:

```text
GET /api/orders/123
        ↓
       ALB
        ↓
     Ingress
        ↓
  API Gateway
        ↓
   Authentication
        ↓
   Authorization
        ↓
   Rate limiting
        ↓
   Order Service
        ↓
   Order Database
```

The exact placement of authentication, rate limiting, TLS, and other policies depends on the chosen architecture.

---

# 25. ShopSphere Evolution

A practical way to build ShopSphere is incrementally:

```text
Phase 1
Docker Compose
    ↓
Nginx API Gateway
    ↓
Microservices
```

Then:

```text
Phase 2
EKS
    ↓
Ingress + AWS Load Balancer Controller
    ↓
Services
    ↓
Pods
```

Then add required API-management capabilities:

```text
Authentication
Authorization
Rate limiting
Request policies
Observability
```

This keeps the architecture understandable while adding capabilities when there is a real requirement for them.

---

## Final Mental Model

```text
                    CLIENT
                       │
                       ▼
                ┌─────────────┐
                │     ALB     │
                │ Load Balance│
                └──────┬──────┘
                       │
                       ▼
                ┌─────────────┐
                │   Ingress   │
                │   Routing   │
                └──────┬──────┘
                       │
                       ▼
                ┌─────────────┐
                │ API Gateway │
                │ API Policies│
                └──────┬──────┘
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
          Product     Order      User
          Service    Service    Service
             │         │
             ▼         ▼
            DB        DB
```

The key principle is:

> **Don't add ALB, Ingress, API Gateway, or any other layer just because it is available. Add each layer when it solves a specific architectural problem.**
