# Kubernetes & Linux Networking Reflections

> This document summarizes everything I learned while understanding Kubernetes internals, Linux networking, Pod networking, Services, and Kind. It is intended as a quick revision guide before interviews or future projects.

---

# 1. What is Kubernetes?

Kubernetes is a container orchestration platform that automates the deployment, scaling, networking, and management of containerized applications.

Kubernetes follows a **Control Plane** and **Worker Node** architecture.

---

# 2. Kubernetes Architecture

## Control Plane

The Control Plane is the brain of Kubernetes.

Components:

* API Server
* etcd
* Controller Manager
* Scheduler

### API Server

* Entry point to Kubernetes.
* Receives every kubectl request.
* Validates requests.
* Stores desired state in etcd.
* Acts as the communication hub between all Kubernetes components.

### etcd

* Distributed Key-Value Database.
* Stores the desired state of the cluster.
* Stores Kubernetes objects like Deployments, Services, ConfigMaps, Secrets, etc.

### Controller Manager

Runs multiple controllers such as:

* Deployment Controller
* ReplicaSet Controller
* Endpoint Controller
* Node Controller

Responsibilities:

* Continuously compares desired state with actual state.
* Reconciles differences.
* Creates/updates Kubernetes resources.

### Scheduler

Responsibilities:

* Chooses the best Worker Node.
* Considers:

  * CPU
  * Memory
  * Scheduling policies
  * Taints & Tolerations
  * Node Affinity

The Scheduler decides **where** a Pod should run.

---

# 3. Worker Node Components

Worker Nodes are where applications actually run.

Components:

* kubelet
* containerd
* CNI
* kube-proxy

---

## kubelet

Node Agent.

Responsibilities:

* Watches API Server.
* Receives Pod specification.
* Asks containerd to create containers.
* Invokes CNI for networking.
* Continuously monitors Pods.
* Reports Pod status back to API Server.

---

## containerd

Container Runtime.

Responsibilities:

* Pull container image
* Create container
* Start container
* Stop container

---

## CNI (Container Network Interface)

Responsibilities:

* Configures Pod networking.
* Creates Pod networking.
* Assigns unique IP to every Pod.
* Enables Pod-to-Pod communication across nodes.

Examples:

* AWS VPC CNI
* Calico
* Flannel
* Cilium
* KindNet

---

## kube-proxy

Responsibilities:

* Watches Service & Endpoint objects.
* Programs Linux networking rules.
* Uses:

  * iptables
  * IPVS
* Routes Service traffic to backend Pods.

---

# 4. Complete Kubernetes Flow

When a Deployment YAML is applied:

```
kubectl apply -f deployment.yaml
        │
        ▼
API Server
        │
Validates request
        │
Stores desired state
        ▼
etcd
        │
Controller Manager
        │
Creates ReplicaSet
        │
Creates Pods
        ▼
Scheduler
        │
Chooses Worker Node
        ▼
kubelet
        │
containerd
        │
Pull Image
        │
Start Container
        ▼
CNI
        │
Assign Pod IP
        ▼
Running Pod
        │
Endpoint Controller
        │
Creates Service → Pod mapping
        ▼
kube-proxy
        │
Programs iptables/IPVS
        ▼
Linux Kernel
        │
Routes traffic
        ▼
Healthy Pod
```

---

# 5. Pod Networking

Each Pod receives:

* Unique IP
* Own network namespace
* Own eth0 interface

Pods can communicate directly with other Pods.

---

# 6. Why Service?

Problem:

Pod IP changes whenever Pod is recreated.

Example:

```
Old Pod

10.244.1.10

↓

Pod Deleted

↓

New Pod

10.244.5.30
```

Applications should never depend on Pod IP.

Solution:

Use a Service.

Service provides:

* Stable endpoint
* Stable DNS
* Load Balancing

---

# 7. Service

Service is a Kubernetes object.

It contains:

* Selector
* ClusterIP
* Port

Example:

```yaml
selector:
  app: nginx
```

Service discovers Pods using labels.

---

# 8. ClusterIP

ClusterIP is:

* Virtual IP
* Not attached to any network interface
* Exists only because kube-proxy programs Linux networking rules.

Example:

```
ClusterIP

10.96.0.10
```

No machine actually owns this IP.

Linux kernel redirects packets before they ever reach it.

---

# 9. Endpoint Controller

Responsibilities:

* Watches Pods
* Watches Services
* Maintains Service → Pod mapping

Example:

```
Service

nginx-service

↓

Endpoints

10.244.1.10

10.244.2.10

10.244.3.10
```

Whenever Pod changes:

Endpoints automatically update.

---

# 10. kube-proxy

kube-proxy watches:

* Service
* Endpoint

Then updates:

* iptables
* IPVS

Example rule:

```
If destination = 10.96.0.10

↓

Forward to

10.244.2.10
```

---

# 11. Linux Networking

Linux networking works using:

* Network Interface
* Routing Table
* Gateway
* iptables

Flow:

```
Application

↓

Linux Kernel

↓

Routing Table

↓

eth0

↓

Gateway

↓

Internet
```

---

# 12. eth0

eth0 is:

* Primary Network Interface
* Entry and Exit point of packets

Example:

```
Google

↓

Router

↓

eth0

↓

Linux Kernel

↓

Application
```

---

# 13. Routing Table

Routing Table decides:

> Where should this packet go?

If destination is:

* Same subnet → Send directly
* Different subnet → Send to Gateway

---

# 14. iptables

iptables is Linux's packet filtering and routing engine.

Responsibilities:

* NAT
* Firewall
* Packet Forwarding
* DNAT
* SNAT

kube-proxy programs these rules.

Linux Kernel executes them.

---

# 15. Kubernetes Networking

Kubernetes does NOT invent networking.

It uses Linux networking.

```
Pod

↓

veth

↓

Bridge

↓

Routing Table

↓

iptables

↓

eth0

↓

Internet
```

Components:

* CNI
* Linux Kernel
* Routing Table
* Bridge
* iptables
* kube-proxy

---

# 16. Why ClusterIP Works

Client sends:

```
10.96.0.10
```

Linux kernel checks:

```
iptables
```

Rule:

```
10.96.0.10

↓

10.244.3.15
```

Packet reaches Pod.

ClusterIP never owns an interface.

---

# 17. Kind

Kind = Kubernetes IN Docker.

Purpose:

* Local Kubernetes Cluster
* Learning
* Testing
* Development
* CI/CD

Kind creates Kubernetes nodes as Docker containers.

---

# 18. Important kubectl Commands

## Create Resources

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

---

## Delete Resources

```bash
kubectl delete -f deployment.yaml
kubectl delete deployment nginx-app
kubectl delete service nginx-service
```

---

## View Resources

```bash
kubectl get pods
kubectl get deploy
kubectl get svc
kubectl get rs
kubectl get nodes
kubectl get endpoints
kubectl get endpointslices
kubectl get all
kubectl get all -A
```

---

## Describe

```bash
kubectl describe pod <pod-name>
kubectl describe deployment <deployment-name>
kubectl describe svc <service-name>
kubectl describe node <node-name>
```

---

## Logs

```bash
kubectl logs <pod-name>
```

---

## Execute

```bash
kubectl exec -it <pod-name> -- /bin/bash
```

---

## Port Forward

```bash
kubectl port-forward svc/nginx-service 8080:80
```

---

## Config

```bash
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <context-name>
```

---

# 19. Kind Commands

## Install

```bash
brew install kind
```

---

## Version

```bash
kind version
```

---

## Create Cluster

```bash
kind create cluster --name dev-cluster
```

---

## List Clusters

```bash
kind get clusters
```

---

## Delete Cluster

```bash
kind delete cluster --name dev-cluster
```

---

# 20. Key Interview Takeaways

* Kubernetes follows Control Plane + Worker Node architecture.
* API Server is the communication hub.
* etcd stores the desired state.
* Controller Manager reconciles desired and actual state.
* Scheduler decides where Pods should run.
* kubelet manages Pods on the node.
* containerd runs containers.
* CNI assigns Pod IPs and enables Pod networking.
* Service provides a stable endpoint.
* Endpoint Controller maintains Service-to-Pod mappings.
* kube-proxy programs iptables/IPVS.
* Linux kernel executes routing rules.
* ClusterIP is a virtual IP.
* Kubernetes networking is built on Linux networking primitives.
* Kind provides a lightweight local Kubernetes cluster for learning and development.

---

# Personal Reflection

The biggest realization from learning Kubernetes networking was understanding that **a Service is only a Kubernetes configuration object and the ClusterIP is a virtual IP**. The actual packet forwarding is performed by the Linux kernel using **iptables/IPVS rules programmed by kube-proxy**, while the **Endpoint Controller** keeps the Service-to-Pod mappings up to date. This helped me connect Linux networking concepts such as **routing tables, network interfaces, and iptables** with Kubernetes internals, making the overall architecture much easier to understand. Kubernetes is not a new networking stack—it is an orchestration layer built on top of the Linux kernel's existing networking capabilities.
