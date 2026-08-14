# Kubernetes Services

A Kubernetes Service provides a stable network endpoint for accessing Pods. Since Pod IPs can change when Pods are recreated, Services provide a consistent way to communicate with application Pods.

The three commonly used Service types are:

- `ClusterIP`
- `NodePort`
- `LoadBalancer`

---

## 1. ClusterIP

`ClusterIP` is the default Kubernetes Service type. It provides an internal IP address and DNS name that can be accessed from within the Kubernetes cluster.

Traffic flow:

```text
Application Pod
      |
      v
payment-service (ClusterIP)
      |
      v
Payment Pods
```

### Usage

ClusterIP is mainly used for **internal microservice-to-microservice communication**.

### Realistic Use Case

In an e-commerce application:

```text
order-service
      |
      v
payment-service
      |
      v
Payment Pods
```

`order-service` can communicate with `payment-service` using its Kubernetes DNS name:

```text
http://payment-service:8080
```

The Payment Service does not need to be exposed to the Internet.

### Advantages

- Internal-only communication.
- Stable IP and DNS name.
- Kubernetes service discovery.
- No external Load Balancer required.
- Ideal for backend microservices.

### Limitation

ClusterIP cannot directly receive traffic from outside the Kubernetes cluster.

### Solution

Use `NodePort` or `LoadBalancer` for external access. For production HTTP/HTTPS applications, use `LoadBalancer` with Ingress/Gateway when multiple Services need to be exposed through one external entry point.

---

# 2. NodePort

`NodePort` exposes a Kubernetes Service through a specific port on the worker nodes.

For example:

```text
Node IP : 30080
```

Traffic flow:

```text
Client
   |
   v
Worker Node :30080
   |
   v
NodePort Service
   |
   v
Application Pod :8000
```

The application still listens on its normal application port, such as `8000`. Kubernetes networking forwards traffic arriving on the NodePort to the Service and then to the appropriate Pod.

### Usage

NodePort is mainly useful for:

- Development
- Testing
- Local Kubernetes environments
- Simple environments where a cloud Load Balancer is not available

### Realistic Use Case

While testing an application on Kind or Minikube, you want to access the application from your local machine without creating an AWS Load Balancer.

```text
Developer
    |
    v
NodeIP:30080
    |
    v
NodePort Service
    |
    v
Application Pods
```

### Advantages

- Simple external access.
- Does not require a cloud Load Balancer.
- Works across different Kubernetes environments.
- Useful for development and testing.

### Limitations

- Uses high-numbered ports (`30000-32767` by default).
- Exposes worker-node ports.
- Network/security configuration becomes more complicated.
- Not convenient for exposing many production microservices.
- Does not provide path-based or host-based application routing.

For example, exposing multiple services could result in:

```text
NodeIP:30001 -> user-service
NodeIP:30002 -> order-service
NodeIP:30003 -> payment-service
```

This is not a clean production architecture.

### Solution

Use a cloud `LoadBalancer` and, when multiple applications need to share one external entry point, use `Ingress` or `Gateway` for routing.

---

# 3. LoadBalancer

`LoadBalancer` exposes a Kubernetes Service through an external cloud Load Balancer.

For example, in AWS:

```text
Internet
    |
    v
AWS Load Balancer
    |
    v
Kubernetes Service
    |
    v
Application Pods
```

The cloud provider provisions the external Load Balancer and provides an external DNS name or IP.

### Usage

Use `LoadBalancer` when an application needs to be directly accessible from outside the Kubernetes cluster.

### Realistic Use Case

A public REST API needs to be accessed from the Internet:

```text
api.example.com
       |
       v
AWS Load Balancer
       |
       v
api-service
       |
       v
API Pods
```

### Advantages

- Provides an external endpoint.
- Cloud provider manages the Load Balancer infrastructure.
- Provides external traffic distribution.
- Supports cloud-provider health checking.
- Better external entry point than directly exposing worker nodes.

### Limitations

A `LoadBalancer` Service normally exposes one Kubernetes Service through an external Load Balancer.

If every microservice gets its own Load Balancer:

```text
Load Balancer -> user-service
Load Balancer -> order-service
Load Balancer -> payment-service
```

this can increase:

- Cost
- Infrastructure complexity
- Operational overhead

Another limitation is that a basic LoadBalancer Service does not provide application-level routing such as:

```text
/api/users     -> user-service
/api/orders    -> order-service
/api/payments  -> payment-service
```

### Solution

Use an `Ingress` or `Gateway` behind the external Load Balancer.

```text
Internet
    |
    v
AWS Load Balancer
    |
    v
Ingress / Gateway
    |
    +----> user-service
    |
    +----> order-service
    |
    +----> payment-service
```

The Ingress/Gateway can route traffic using:

- Hostnames
- URL paths
- HTTPS/TLS rules

---

# Production Microservices Architecture

For a typical production microservices application, we do not normally create a separate public Load Balancer for every internal microservice.

Instead, we use one external entry point:

```text
                         Internet
                            |
                            v
                    AWS Load Balancer
                            |
                            v
                     Ingress / Gateway
                       /      |       \
                      /       |        \
                     v        v         v
              user-service order-service payment-service
                   |           |            |
                   v           v            v
                 Pods        Pods         Pods
```

The individual microservices remain internal `ClusterIP` Services.

For example:

```text
Order Pod
    |
    v
payment-service
   (ClusterIP)
    |
    v
Payment Pods
```

The Order Service does not need to go through the external Load Balancer to communicate with the Payment Service.

---

# Comparison

| Service Type | Purpose | External Access | Typical Use |
|---|---|---|---|
| `ClusterIP` | Internal communication | No | Microservice-to-microservice |
| `NodePort` | Expose Service through worker-node port | Yes | Development/testing |
| `LoadBalancer` | Expose Service through cloud Load Balancer | Yes | Public applications |

---

# Key Difference

```text
ClusterIP
    |
    +-- Internal communication
        Service -> Service -> Pods


NodePort
    |
    +-- Simple external access
        NodeIP:NodePort -> Service -> Pods


LoadBalancer
    |
    +-- External cloud access
        Load Balancer -> Service -> Pods


Ingress / Gateway
    |
    +-- Application-level routing
        Load Balancer
             |
             v
        Ingress/Gateway
          /    |    \
         v     v     v
      Service Service Service
```

## Final Takeaway

- **ClusterIP** → Use for internal communication between microservices.
- **NodePort** → Use for simple external access, mainly during development and testing.
- **LoadBalancer** → Use when a Service needs a cloud-managed external endpoint.
- **Ingress/Gateway** → Use when external traffic needs to be routed to multiple Kubernetes Services based on hostname, path, or other HTTP rules.

The common production pattern is:

```text
Internet
    |
    v
Cloud Load Balancer
    |
    v
Ingress / Gateway
    |
    +----> ClusterIP Service ----> Pods
    |
    +----> ClusterIP Service ----> Pods
    |
    +----> ClusterIP Service ----> Pods
```

**ClusterIP provides internal connectivity, NodePort provides basic node-level external access, LoadBalancer provides cloud-level external access, and Ingress/Gateway provides intelligent routing across multiple Services.**