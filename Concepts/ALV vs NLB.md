# AWS ALB vs NLB

# What is ALB?

ALB (Application Load Balancer) is a Layer 7 load balancer.

It understands:

* HTTP
* HTTPS
* URLs
* Headers
* Cookies
* Hostnames

ALB makes routing decisions based on application-level data.

Example:

```text id="8e7d4j"
/api → API servers
/admin → Admin servers
```

Best for:

* Websites
* REST APIs
* Microservices
* Kubernetes ingress
* HTTPS applications

---

# What is NLB?

NLB (Network Load Balancer) is a Layer 4 load balancer.

It understands:

* TCP
* UDP
* IP
* Port

NLB does NOT understand:

* URLs
* paths
* headers
* cookies

NLB focuses on:

* ultra-high performance
* very low latency
* raw network traffic forwarding

Best for:

* Gaming
* Streaming
* Banking systems
* MQTT
* VoIP
* TCP/UDP workloads

---

# Core Difference

| Feature             | ALB        | NLB            |
| ------------------- | ---------- | -------------- |
| OSI Layer           | Layer 7    | Layer 4        |
| Protocol            | HTTP/HTTPS | TCP/UDP        |
| Path Routing        | Yes        | No             |
| Host Routing        | Yes        | No             |
| SSL Termination     | Excellent  | Limited        |
| Static IP           | No         | Yes            |
| Performance         | High       | Extremely High |
| Latency             | Low        | Ultra Low      |
| Intelligent Routing | Yes        | No             |

---

# Traffic Flow

## ALB

```text id="6l2gfg"
User
 ↓
ALB
 ↓
Checks URL / Host / Headers
 ↓
Routes traffic intelligently
```

---

## NLB

```text id="k8zhdv"
User
 ↓
NLB
 ↓
Fast TCP/UDP forwarding
```

---

# When to Use ALB?

Use ALB when application needs:

* HTTPS
* URL-based routing
* Host-based routing
* Microservices
* APIs
* Web applications
* WAF integration

---

# When to Use NLB?

Use NLB when application needs:

* Ultra low latency
* Millions of TCP connections
* UDP traffic
* Static IPs
* High throughput
* Gaming or streaming traffic

---

# What We Used in Our Project?

We used:

```text id="0zrfhp"
Application Load Balancer (ALB)
```

Because our Student Profile Application required:

* HTTP/HTTPS traffic
* ACM SSL certificate
* Route53 integration
* Health checks
* Auto Scaling integration
* Layer 7 intelligent routing

---

# Important Interview Question

## Q) Why did you choose ALB instead of NLB in your project?

### Answer

```text id="fg8jmn"
We used ALB because our application was HTTP/HTTPS based
and required Layer 7 intelligent routing, HTTPS termination,
health checks, Route53 integration, and Auto Scaling support.

ALB is ideal for web applications and APIs where application-level
routing is required.
```

---

# Important Interview Question

## Q) When would you choose NLB over ALB?

### Answer

```text id="b3aq9g"
I would choose NLB for ultra-low latency TCP/UDP workloads
such as gaming servers, streaming platforms, financial systems,
or applications requiring static IP addresses and very high throughput.
```

---

# Final One-Line Difference

```text id="8yn2pj"
ALB = Smart HTTP/HTTPS routing
NLB = Ultra-fast TCP/UDP forwarding
```
