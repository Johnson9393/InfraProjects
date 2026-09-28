# CloudNativePG (CNPG) — Practical Kubernetes Lab

## 1. What is CNPG?

CNPG stands for **CloudNativePG**.

CNPG is a Kubernetes Operator specifically designed to create and manage PostgreSQL databases inside Kubernetes.

The basic idea is:

Kubernetes
    |
    +-- CNPG Operator
            |
            +-- PostgreSQL

The CNPG Operator understands how PostgreSQL should be managed and uses Kubernetes resources to run and manage PostgreSQL.

---

## 2. What is a Kubernetes Operator?

A Kubernetes Operator is software that runs inside Kubernetes and understands how to manage a specific application.

In our case:

CNPG Operator
    |
    +-- understands PostgreSQL
    +-- creates PostgreSQL resources
    +-- manages PostgreSQL instances
    +-- manages PostgreSQL-specific behavior

The important mental model is:

> Operator = software that teaches Kubernetes how to manage a specific application.

---

## 3. What We Built in This Lab

We created a local Kubernetes environment using Kind.

Our environment is:

Kind Kubernetes Cluster
    |
    +-- CNPG Operator
            |
            +-- PostgreSQL Cluster
                    |
                    +-- PostgreSQL Instance
                            |
                            +-- Kubernetes Pod
                                postgres-cluster-1

---

## 4. Installing the CNPG Operator

After creating the Kind cluster, we installed the CNPG Operator.

The Operator runs inside the `cnpg-system` namespace.

We verified it using:

    kubectl get pods -n cnpg-system

The CNPG controller manager was running successfully.

We also verified that CNPG installed its Custom Resource Definitions (CRDs).

One important CRD is:

    clusters.postgresql.cnpg.io

This allows Kubernetes to understand the CNPG `Cluster` resource.

---

## 5. Creating the PostgreSQL Cluster

We created a CNPG Cluster using a YAML file.

The important part of our configuration was:

    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: postgres-cluster
    spec:
      instances: 1
      storage:
        size: 1Gi

The important concepts are:

- `kind: Cluster` represents a CNPG PostgreSQL Cluster.
- `instances: 1` tells CNPG to create one PostgreSQL instance.
- `storage.size: 1Gi` requests 1 GiB of persistent storage.

---

## 6. PostgreSQL Cluster vs PostgreSQL Instance

Our current configuration is:

    PostgreSQL Cluster
            |
            +-- PostgreSQL Instance
                    |
                    +-- Kubernetes Pod
                        postgres-cluster-1

Because we configured:

    instances: 1

we currently have:

    1 PostgreSQL Cluster
        |
        +-- 1 PostgreSQL Instance
                |
                +-- 1 Kubernetes Pod

The Pod `postgres-cluster-1` is running the PostgreSQL instance.

That PostgreSQL instance is currently the primary instance.

---

## 7. The PostgreSQL Pod

We verified the Pod using:

    kubectl get pods

We currently have:

    postgres-cluster-1   1/1   Running

CNPG created this Pod automatically from the CNPG `Cluster` resource.

We did not manually create a Deployment, StatefulSet, or PostgreSQL Pod.

The CNPG Operator handles the creation and management of the PostgreSQL resources.

---

## 8. Persistent Storage

We configured:

    storage:
      size: 1Gi

CNPG automatically created a PersistentVolumeClaim (PVC) for the PostgreSQL instance.

We verified it using:

    kubectl get pvc

The PVC was:

    postgres-cluster-1
    STATUS: Bound
    CAPACITY: 1Gi
    STORAGECLASS: standard

The Kind cluster's `standard` StorageClass dynamically provisions the underlying PersistentVolume.

The simplified storage relationship is:

    PostgreSQL Pod
          |
          +-- PVC
                |
                +-- PV
                      |
                      +-- Persistent Storage

The important database principle is:

> The Pod is replaceable; persistent storage is what preserves the database data.

The PostgreSQL process runs inside the Pod, while the persistent database data is stored on persistent storage.

---

## 9. CNPG Automatically Creates Kubernetes Resources

We only created one CNPG `Cluster` resource.

CNPG then created and manages the required Kubernetes resources for the PostgreSQL instance.

For our current lab, this includes:

    CNPG Cluster
         |
         +-- PostgreSQL Pod
         |
         +-- Persistent Storage
         |
         +-- PostgreSQL Services

The important point is that the Operator is doing the orchestration for us.

We do not have to manually create every PostgreSQL-related Kubernetes resource.

---

## 10. PostgreSQL Read-Write Service

CNPG created a Service called:

    postgres-cluster-rw

The `rw` means:

    Read-Write

This is the Service intended for applications that need to communicate with the PostgreSQL primary for normal database operations such as:

- SELECT
- INSERT
- UPDATE
- DELETE

We inspected the Service using:

    kubectl describe service postgres-cluster-rw

Important output:

    Type: ClusterIP

    IP: 10.96.114.173

    Port: 5432/TCP

    TargetPort: 5432/TCP

    Endpoints: 10.244.0.8:5432

The Service has a ClusterIP:

    10.96.114.173

The PostgreSQL Pod has its own Pod IP:

    10.244.0.8

These are different IP addresses.

---

## 11. How the Read-Write Service Finds the PostgreSQL Pod

The `postgres-cluster-rw` Service has this selector:

    cnpg.io/cluster=postgres-cluster
    cnpg.io/instanceRole=primary

These labels were NOT manually defined by us.

CNPG automatically adds the appropriate labels to the PostgreSQL Pod when it creates the Pod.

The relationship is:

    CNPG Cluster
          |
          +-- CNPG Operator
                  |
                  +-- creates PostgreSQL Pod
                  |       |
                  |       +-- adds CNPG labels
                  |
                  +-- creates RW Service
                          |
                          +-- selector matches those labels

The Service therefore identifies the current PostgreSQL primary using the CNPG-managed labels.

---

## 12. Read-Write Service Communication

The current communication path is:

    Application
         |
         | connects to postgres-cluster-rw:5432
         |
         v
    Kubernetes Service
         |
         | ClusterIP
         |
         v
    Service Endpoint
         |
         | 10.244.0.8:5432
         |
         v
    postgres-cluster-1 Pod
         |
         v
    PostgreSQL Instance
         |
         v
    Persistent Storage

The key distinction is:

Service:
    Determines WHERE the application should send database traffic.

Persistent Storage:
    Determines WHERE PostgreSQL's persistent data is stored.

These are separate concepts.

---

## 13. Current Lab State

At this stage, our lab looks like:

    Kind Kubernetes Cluster
            |
            +-- CNPG Operator
            |
            +-- PostgreSQL Cluster
                    |
                    +-- PostgreSQL Instance
                    |       |
                    |       +-- Pod: postgres-cluster-1
                    |
                    +-- Persistent Storage
                    |       |
                    |       +-- PVC: postgres-cluster-1
                    |       +-- PV
                    |
                    +-- RW Service
                            |
                            +-- ClusterIP
                            +-- Selector
                            +-- PostgreSQL primary endpoint

---

## 14. Key Takeaways

1. CNPG is CloudNativePG, a Kubernetes Operator for PostgreSQL.

2. The CNPG Operator runs inside Kubernetes and manages PostgreSQL.

3. We create a CNPG `Cluster` resource instead of manually creating all PostgreSQL Kubernetes resources.

4. `instances: 1` means our CNPG PostgreSQL Cluster currently has one PostgreSQL instance.

5. That PostgreSQL instance is running inside the Pod:

       postgres-cluster-1

6. The PostgreSQL Pod is backed by persistent storage.

7. CNPG automatically created the PVC and Kubernetes-managed storage relationship for us.

8. The Pod is replaceable, but persistent storage preserves the database data.

9. CNPG automatically created the `postgres-cluster-rw` Service.

10. `rw` means Read-Write.

11. The RW Service uses CNPG-managed Pod labels to identify the PostgreSQL primary.

12. The Service has a ClusterIP, while the PostgreSQL Pod has its own Pod IP.

13. Service routing and persistent storage are separate concepts.

---

## Current Mental Model

    CNPG Operator
          |
          v
    PostgreSQL Cluster
          |
          v
    PostgreSQL Instance
          |
          v
    PostgreSQL Pod
          |
          +------> Persistent Storage
          |
          +------> RW Service
                          |
                          v
                    Application