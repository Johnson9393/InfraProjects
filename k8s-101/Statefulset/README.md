# Kubernetes StatefulSet & Persistent Storage — Practical Notes

This README contains the concepts learned so far about Kubernetes StatefulSets, persistent storage, PersistentVolumes (PV), PersistentVolumeClaims (PVC), StorageClasses, CSI drivers, EBS, EFS, access modes, Headless Services, static provisioning, dynamic provisioning, and `volumeClaimTemplates`.

The goal is to understand not only what these resources are, but also why they exist, how they work together, and when they are useful.

---

# 1. Stateless vs Stateful Applications

Kubernetes applications can broadly be divided into:

- Stateless workloads
- Stateful workloads

## Stateless workload

A stateless application does not need a particular pod to preserve its identity or local data.

Example:

- Frontend
- Backend API
- REST API
- Web server
- Microservice

If we have:

    backend-pod-1
    backend-pod-2
    backend-pod-3

Any pod can process a request.

If `backend-pod-2` dies, Kubernetes can simply create another pod.

The new pod does not need to be the same logical pod.

This is why Deployments are commonly used for stateless workloads.

## Stateful workload

A stateful application may need:

- Persistent data
- Stable identity
- Stable network identity/discovery
- Ordered startup/shutdown
- Individual storage for individual replicas

Examples:

- PostgreSQL
- MySQL
- MongoDB
- Kafka
- Elasticsearch
- ZooKeeper
- Redis clusters

This is where StatefulSet becomes useful.

---

# 2. Deployment

A Deployment is generally used for stateless applications.

Conceptually:

    Deployment
        |
        v
    ReplicaSet
        |
        +---- Pod
        +---- Pod
        +---- Pod

Suppose we have three backend pods:

    backend-pod-A
    backend-pod-B
    backend-pod-C

These pods are generally interchangeable.

If `backend-pod-B` dies:

    backend-pod-A
    backend-pod-C
    backend-pod-D

The replacement pod does not need the same identity as the deleted pod.

The application normally does not care which specific pod handles the request.

Typical flow:

    Client
       |
       v
    Kubernetes Service
       |
       +----> Backend Pod
       +----> Backend Pod
       +----> Backend Pod

The Service distributes traffic to available matching pods.

---

# 3. StatefulSet

A StatefulSet is designed for workloads where individual pods need stable identity and/or persistent storage.

Example:

    StatefulSet
        |
        +---- postgres-0
        +---- postgres-1
        +---- postgres-2

The pod names are predictable.

If `postgres-1` is deleted:

    postgres-0
    postgres-2

Kubernetes recreates:

    postgres-1

It does not create:

    postgres-3

Therefore:

    Deployment
        -> interchangeable pod identity

    StatefulSet
        -> stable logical pod identity

---

# 4. Why Stable Identity Matters

Consider a database cluster:

    postgres-0
    postgres-1
    postgres-2

Conceptually:

    postgres-0 = primary
    postgres-1 = replica
    postgres-2 = replica

The database cluster may need to know which logical member is which.

If a pod is recreated, we still want the replacement to represent the same logical member.

Therefore:

    postgres-1
       |
       | crashes
       v
    postgres-1 recreated

The identity remains:

    postgres-1

This is one of the major reasons StatefulSet exists.

---

# 5. Pod Identity vs Worker Node

A StatefulSet pod is NOT a worker node.

For example:

    EKS Cluster
       |
       +---- Worker Node 1
       |       |
       |       +---- application pod
       |       +---- application pod
       |
       +---- Worker Node 2
               |
               +---- postgres-0

`postgres-0` is a pod.

The worker node is the compute machine on which the pod runs.

Kubernetes can schedule pods onto available worker nodes according to scheduling constraints.

In enterprise architectures, databases may also be placed on separate infrastructure or external services such as Amazon RDS.

---

# 6. StatefulSet Does NOT Provide a Permanent Pod IP

This is an important distinction.

StatefulSet provides stable logical identity.

It does NOT guarantee that the pod's IP address remains permanently unchanged.

Example:

    postgres-0
       |
       +---- Pod IP: 10.0.1.25

If the pod is recreated:

    postgres-0
       |
       +---- Pod IP: 10.0.2.41

The identity is still:

    postgres-0

But the IP can change.

This is why Kubernetes DNS and Services are important.

---

# 7. Kubernetes Service

A normal Kubernetes Service provides a stable network identity for a group of pods.

Example:

    backend-service

The Service has a stable ClusterIP.

Conceptually:

    Client
       |
       v
    backend-service
       |
       v
    ClusterIP
       |
       +----> Pod 1
       +----> Pod 2
       +----> Pod 3

The pod IPs can change.

The Service remains stable.

Kubernetes continuously maintains the endpoints associated with the Service.

If a pod dies:

    Old Pod IP
       |
       X removed

If a replacement pod becomes healthy:

    New Pod IP
       |
       +---- added

The application continues using the Service.

---

# 8. Headless Service

A Headless Service is a Service configured with:

    clusterIP: None

Unlike a normal Service, it does not provide a virtual ClusterIP.

Instead, Kubernetes DNS can return the individual pod endpoints associated with the Service.

This is especially useful with StatefulSets.

Conceptually:

    Application
        |
        v
    Headless Service DNS
        |
        +----> postgres-0
        +----> postgres-1
        +----> postgres-2

This allows applications to discover individual StatefulSet members.

---

# 9. Normal Service vs Headless Service

## Normal Service

Mental model:

    "Give me any healthy pod that matches this Service."

Example:

    backend-service
        |
        +----> backend-pod-1
        +----> backend-pod-2
        +----> backend-pod-3

The client normally does not care which pod it reaches.

## Headless Service

Mental model:

    "Help me discover the individual pods."

Example:

    postgres-0
    postgres-1
    postgres-2

This is useful when individual members matter.

---

# 10. StatefulSet + Headless Service

StatefulSet and Headless Service are commonly used together.

StatefulSet provides:

    Stable pod identity

Headless Service provides:

    Individual pod discovery through DNS

Together:

    StatefulSet
        |
        +---- postgres-0
        +---- postgres-1
        +---- postgres-2
                 |
                 v
        Headless Service
                 |
                 v
        DNS-based discovery

The important point is:

    StatefulSet = stable logical identity

    Headless Service = network discovery of individual endpoints

---

# 11. Why Persistent Storage Is Needed

A container's writable filesystem should not be treated as durable database storage.

Suppose:

    postgres-0
       |
       +---- container filesystem
       |
       +---- database data

If the pod is removed and recreated, the container filesystem may not contain the previous database data.

For important application data, we need persistent storage.

The desired architecture is:

    Pod
      |
      v
    Persistent Storage
      |
      v
    Data survives pod replacement

Therefore:

    Pod lifecycle
        !=
    Storage lifecycle

This separation is one of the key concepts behind persistent storage in Kubernetes.

---

# 12. PersistentVolume (PV)

A PersistentVolume is a Kubernetes representation of persistent storage.

Think of a PV as:

    "A piece of persistent storage made available to Kubernetes."

The underlying storage could be:

- Amazon EBS
- Amazon EFS
- NFS
- Other supported storage systems

Conceptually:

    Kubernetes
        |
        v
    PersistentVolume
        |
        v
    Actual Storage

A PV is generally considered the supply side of persistent storage.

---

# 13. PersistentVolumeClaim (PVC)

A PersistentVolumeClaim is a request for persistent storage.

Think of it as:

    "Application wants storage with these requirements."

For example:

    Storage required: 20Gi
    Access mode: ReadWriteOnce

The PVC is the demand/request side.

Therefore:

    PV  = storage supply

    PVC = storage request/claim

---

# 14. PV vs PVC

A useful mental model:

    PV
    |
    | "I provide 20Gi of storage."
    |
    v

    PVC
    |
    | "I need 20Gi of storage."
    |
    v

    Pod

The application normally references the PVC.

The application does not normally need to know which specific PV or physical disk it is using.

---

# 15. Basic Persistent Storage Chain

The basic relationship is:

    Pod
      |
      v
    PVC
      |
      v
    PV
      |
      v
    Actual Storage

For AWS:

    Pod
      |
      v
    PVC
      |
      v
    PV
      |
      v
    EBS

For shared filesystem storage:

    Pod
      |
      v
    PVC
      |
      v
    PV
      |
      v
    EFS

---

# 16. EBS

Amazon EBS stands for Elastic Block Store.

A useful mental model is:

    EBS = persistent virtual disk

EBS is commonly appropriate for workloads that need their own persistent block storage.

Example:

    PostgreSQL
        |
        v
    PVC
        |
        v
    PV
        |
        v
    EBS volume

A database can store its data on that persistent volume.

---

# 17. EFS

Amazon EFS stands for Elastic File System.

A useful mental model is:

    EFS = shared network filesystem

EFS is useful when multiple pods or nodes need access to the same filesystem.

Conceptually:

    EFS
     |
     +---- Pod 1
     |
     +---- Pod 2
     |
     +---- Pod 3

Multiple workloads can access the shared filesystem according to the configured access mode and filesystem permissions.

---

# 18. EBS vs EFS

A simple mental shortcut:

    EBS
      =
    Persistent disk

    EFS
      =
    Shared filesystem

Typical conceptual use:

    Database
       |
       v
    EBS

    Multiple pods sharing files
       |
       v
    EFS

The exact storage choice depends on application requirements.

---

# 19. Access Modes

A PVC can specify how the storage should be accessed.

The important Kubernetes access modes are:

- RWO — ReadWriteOnce
- ROX — ReadOnlyMany
- RWX — ReadWriteMany

---

# 20. RWO — ReadWriteOnce

RWO means:

    ReadWriteOnce

For the common EBS mental model:

    One node at a time
    can mount the volume read/write.

Example:

    Node 1
       |
       +---- EBS volume
             Read/Write

    Node 2
       |
       X---- Cannot simultaneously mount that volume
             as read/write under the RWO model

RWO does NOT mean:

    "This volume can permanently belong to one particular node."

It means:

    "One node at a time can use it in the allowed read/write mode."

If the volume is detached from Node 1 and can be safely attached to Node 2, Node 2 can then use it.

---

# 21. RWX — ReadWriteMany

RWX means:

    ReadWriteMany

Multiple nodes can mount the volume and read/write to it simultaneously, provided the storage backend supports it.

EFS is a common example.

Conceptually:

    EFS
      |
      +---- Node 1 / Pod 1
      |
      +---- Node 2 / Pod 2
      |
      +---- Node 3 / Pod 3

If Pod 1 writes a file to the shared filesystem, other pods using the same filesystem can potentially see that file according to normal filesystem semantics and permissions.

---

# 22. ROX — ReadOnlyMany

ROX means:

    ReadOnlyMany

Multiple nodes can mount the volume as read-only, provided the storage backend supports it.

Conceptual example:

    Shared application data
          |
          v
        Volume
          |
          +---- Pod 1 (Read Only)
          +---- Pod 2 (Read Only)
          +---- Pod 3 (Read Only)

---

# 23. StorageClass

A StorageClass defines how storage should be dynamically provisioned.

Think of a StorageClass as:

    "A storage blueprint."

It can define things such as:

- Which provisioner should create the storage
- Storage type
- Parameters
- Reclaim behavior
- Binding behavior
- Expansion behavior

Example conceptual StorageClass:

    kind: StorageClass

    metadata:
      name: ebs-sc

    provisioner:
      ebs.csi.aws.com

The StorageClass tells Kubernetes which provisioning mechanism to use.

---

# 24. CSI Driver

CSI stands for:

    Container Storage Interface

A CSI driver allows Kubernetes to communicate with a particular storage system.

For AWS EBS:

    EBS CSI Driver

The EBS CSI Driver knows how to communicate with AWS EBS and perform storage operations.

For example, it can help Kubernetes:

- Provision EBS volumes
- Attach volumes
- Detach volumes
- Mount volumes
- Manage volume lifecycle
- Support snapshots and other capabilities depending on configuration

---

# 25. StorageClass vs CSI Driver

These two concepts are related but different.

## CSI Driver

The CSI driver knows:

    "HOW to communicate with AWS EBS."

## StorageClass

The StorageClass defines:

    "WHICH storage configuration/provisioning behavior should be used."

A useful analogy:

    CSI Driver
        =
    Mechanic who knows how to operate the machine

    StorageClass
        =
    Configuration/instructions describing what kind of machine/service is required

---

# 26. Complete Dynamic Provisioning Flow

For EKS with EBS:

    Application
        |
        v
    PVC
        |
        v
    StorageClass
        |
        v
    EBS CSI Driver
        |
        v
    AWS EBS
        |
        v
    PV
        |
        v
    Pod consumes the PVC

Conceptually:

    PVC
      |
      v
    StorageClass
      |
      v
    EBS CSI Driver
      |
      v
    EBS Volume
      |
      v
    PV
      |
      v
    PVC becomes Bound
      |
      v
    Pod mounts PVC

The exact controller/attachment lifecycle has more Kubernetes components internally, but this is the correct high-level mental model.

---

# 27. Static Provisioning

Static provisioning means the storage already exists before Kubernetes dynamically provisions it.

Example:

    Administrator
         |
         v
    Manually create EBS
         |
         v
    Create PV
         |
         v
    Create PVC
         |
         v
    Pod

Conceptually:

    Existing EBS
       |
       v
    PV
       |
       v
    PVC
       |
       v
    Pod

The administrator is responsible for preparing the storage.

---

# 28. Static Provisioning Example

Suppose an administrator manually creates a 20Gi EBS volume.

Then Kubernetes is configured with a PV representing that storage.

Conceptually:

    AWS EBS
      20Gi
       |
       v
    PV
      20Gi
       |
       v
    PVC
      requests 20Gi
       |
       v
    Pod

The PVC is matched with the available PV.

Once successfully matched:

    PVC
       |
       v
    Bound
       |
       v
    PV

---

# 29. Dynamic Provisioning

Dynamic provisioning means Kubernetes provisions the storage automatically when a PVC requests it.

Example:

    Application creates PVC
          |
          v
    StorageClass
          |
          v
    EBS CSI Driver
          |
          v
    AWS EBS volume automatically created
          |
          v
    PV automatically created
          |
          v
    PVC becomes Bound
          |
          v
    Pod uses the PVC

The administrator does not need to manually create every EBS volume.

---

# 30. Why Dynamic Provisioning Is Useful

Imagine we need 100 persistent volumes.

With static provisioning:

    Manually create EBS-1
    Manually create EBS-2
    Manually create EBS-3
    ...
    Manually create EBS-100

Then:

    Create PV-1
    Create PV-2
    ...
    Create PV-100

Then create and configure the corresponding PVCs.

This becomes operationally expensive and error-prone.

With dynamic provisioning:

    StorageClass
          |
          v
    EBS CSI Driver

Then applications can create PVCs.

For example:

    PVC-1
    PVC-2
    PVC-3
    ...
    PVC-100

The provisioning system can dynamically create the corresponding storage.

Therefore:

    100 PVCs
        |
        v
    StorageClass
        |
        v
    EBS CSI Driver
        |
        v
    100 EBS volumes

The important point is:

    One PVC normally represents one storage claim.

We do NOT normally create one PVC saying:

    "Give me 100 EBS volumes."

Instead:

    100 PVCs
        ->
    100 individual storage claims

Dynamic provisioning automates the creation of the underlying storage.

---

# 31. Static vs Dynamic Provisioning

## Static

Storage is prepared first.

    Admin
      |
      v
    EBS
      |
      v
    PV
      |
      v
    PVC
      |
      v
    Pod

Characteristics:

- Manual
- Explicit
- Useful when storage already exists
- Useful when administrators need precise control over pre-existing storage
- More operational work at large scale

## Dynamic

Application requests storage.

    PVC
      |
      v
    StorageClass
      |
      v
    CSI Driver
      |
      v
    EBS
      |
      v
    PV
      |
      v
    Pod

Characteristics:

- Automated
- Scales better
- Avoids manually preparing every volume
- Commonly used in modern cloud Kubernetes environments

The important point is not:

    Dynamic is always better.

The correct understanding is:

    Static = storage is manually prepared.

    Dynamic = storage is automatically provisioned according to a defined storage policy.

---

# 32. Why We Need volumeClaimTemplates

StatefulSet replicas commonly need individual storage.

Suppose we have:

    postgres-0
    postgres-1
    postgres-2

We generally do NOT want:

    postgres-0
        |
        +---- same database disk
              ^
              |
    postgres-1
        |
        +---- same database disk
              ^
              |
    postgres-2

Instead, each StatefulSet replica can have its own storage:

    postgres-0
        |
        v
    PVC-0
        |
        v
    EBS-0

    postgres-1
        |
        v
    PVC-1
        |
        v
    EBS-1

    postgres-2
        |
        v
    PVC-2
        |
        v
    EBS-2

This is where `volumeClaimTemplates` becomes very useful.

---

# 33. volumeClaimTemplates

`volumeClaimTemplates` is essentially a PVC template inside a StatefulSet.

Instead of manually creating a PVC for every StatefulSet replica, we define the PVC requirements once.

Conceptually:

    StatefulSet
        |
        +---- volumeClaimTemplate
                    |
                    | 20Gi
                    | RWO
                    | StorageClass = ebs-sc
                    |
                    v
             Kubernetes creates
             individual PVCs
                    |
                    +---- PVC for pod-0
                    +---- PVC for pod-1
                    +---- PVC for pod-2

If the StatefulSet has:

    replicas: 3

The result is conceptually:

    Pod-0 -> PVC-0 -> Volume-0
    Pod-1 -> PVC-1 -> Volume-1
    Pod-2 -> PVC-2 -> Volume-2

If the StatefulSet has:

    replicas: 100

The template can cause Kubernetes to create:

    100 pods
    100 PVCs

with each pod associated with its own claim.

The important point:

    volumeClaimTemplates = define the PVC requirements once

    StatefulSet = creates an individual claim for each replica

---

# 34. volumeClaimTemplates Does Not Mean One PVC for 100 Volumes

This distinction is important.

A template does NOT mean:

    1 PVC -> 100 EBS volumes

Instead:

    1 template
        |
        v
    100 StatefulSet replicas
        |
        v
    100 PVCs
        |
        v
    100 dynamically provisioned volumes

So the template removes the need to manually write 100 separate PVC definitions.

---

# 35. StatefulSet + Dynamic Provisioning

This is one of the most useful combinations.

Conceptually:

    StatefulSet
        |
        | replicas: 3
        |
        v
    volumeClaimTemplates
        |
        +---- PVC-0
        +---- PVC-1
        +---- PVC-2
                 |
                 v
            StorageClass
                 |
                 v
          EBS CSI Driver
                 |
                 v
            EBS volumes
                 |
                 +---- EBS-0
                 +---- EBS-1
                 +---- EBS-2

This gives us:

    Stable pod identity
    +
    Individual persistent storage
    +
    Automatic storage provisioning

---

# 36. Pod Failure and Persistent Storage

Suppose:

    postgres-0
        |
        v
    PVC-0
        |
        v
    EBS-0
        |
        v
    Database data

Now `postgres-0` crashes.

The pod may disappear:

    postgres-0
        X

But normally:

    PVC-0
        |
        v
    EBS-0
        |
        v
    Database data

still exists.

The StatefulSet controller recreates:

    postgres-0

The replacement pod can use the existing PVC:

    postgres-0
        |
        v
    Existing PVC-0
        |
        v
    Existing EBS-0
        |
        v
    Existing database data

This is the core persistence behavior we want.

---

# 37. Why This Is Different from Pod Local Storage

Without persistent storage:

    Pod
      |
      v
    Container filesystem

If the pod is replaced, important data stored only there should not be considered durable.

With persistent storage:

    Pod
      |
      v
    PVC
      |
      v
    PV
      |
      v
    EBS
      |
      v
    Data

The storage exists independently of the pod lifecycle.

Therefore:

    Pod can be replaced

while:

    Persistent data remains

---

# 38. StatefulSet Pod Identity + PVC

A useful mental model is:

    postgres-0
        |
        +---- PVC-0
                |
                +---- EBS-0

    postgres-1
        |
        +---- PVC-1
                |
                +---- EBS-1

    postgres-2
        |
        +---- PVC-2
                |
                +---- EBS-2

If `postgres-1` is recreated:

    postgres-1
        |
        +---- existing PVC-1
                |
                +---- existing EBS-1

The goal is that the replacement pod reconnects to the persistent storage associated with its logical identity.

---

# 39. StatefulSet Deletion vs PVC Deletion

Deleting a StatefulSet does NOT automatically mean that all PVCs are immediately deleted.

Typically:

    Delete StatefulSet
          |
          v
    StatefulSet controller removed
          |
          v
    Pods removed

The PVCs generally remain unless separately deleted or managed by an explicit retention/deletion behavior.

This is important because persistent data should not accidentally disappear simply because the StatefulSet object was removed.

---

# 40. Reclaim Policy

A PersistentVolume can have a reclaim policy.

Common policies include:

- Retain
- Delete

The reclaim policy controls what happens to the storage when the PV is released from its claim.

---

# 41. Retain

`Retain` means the storage is retained after the claim is released.

Conceptually:

    PVC
      |
      v
    PV
      |
      v
    EBS
      |
      v
    Data

PVC is deleted.

The PV becomes released.

With `Retain`:

    PV/data are retained

The administrator can inspect, recover, or manually reuse the storage as appropriate.

Mental model:

    Retain = "Keep the storage/data."

This is useful when protecting important data from accidental deletion.

---

# 42. Delete

`Delete` means the storage provisioner can delete the underlying dynamically provisioned storage when the PV lifecycle reaches deletion.

For dynamically provisioned EBS:

    PVC deleted
        |
        v
    PV released/deleted according to lifecycle
        |
        v
    Dynamically provisioned EBS deleted
        |
        v
    Data lost

Therefore:

    Delete = automatic cleanup of dynamically provisioned storage

This is convenient but potentially destructive.

---

# 43. Important Reclaim Policy Detail

Do not think:

    "Delete StatefulSet = EBS immediately deleted."

That is not the correct model.

The StatefulSet, PVC, PV, and underlying volume have related but distinct lifecycles.

A simplified lifecycle is:

    StatefulSet
        |
        v
    Pod
        |
        v
    PVC
        |
        v
    PV
        |
        v
    EBS

Deleting the StatefulSet generally removes the StatefulSet and its pods.

The PVC can remain.

The reclaim policy becomes relevant when the PV is released as part of the claim/PV lifecycle.

---

# 44. Static Provisioning + Reclaim Policy

Static provisioning requires some additional nuance.

Suppose an administrator manually created an EBS volume:

    Manually created EBS
          |
          v
    Static PV
          |
          v
    PVC

If the PVC is deleted, the PV may become released.

With a manually created/static EBS volume, `Delete` does not necessarily mean that the manually created EBS will automatically disappear.

The exact behavior depends on the storage plugin/CSI configuration and how the PV is configured.

The important practical distinction is:

    Dynamic provisioning
        ->
    Kubernetes/CSI created the underlying volume

    Static provisioning
        ->
    Administrator already created the underlying volume

Therefore, be especially careful with `Delete` when using dynamically provisioned production storage.

---

# 45. Complete Mental Model

At this point, the entire architecture can be visualized as:

    StatefulSet
         |
         | creates/manages
         v
    StatefulSet Pods
         |
         +---- postgres-0
         |        |
         |        +---- PVC-0
         |               |
         |               +---- PV-0
         |                      |
         |                      +---- EBS-0
         |
         +---- postgres-1
         |        |
         |        +---- PVC-1
         |               |
         |               +---- PV-1
         |                      |
         |                      +---- EBS-1
         |
         +---- postgres-2
                  |
                  +---- PVC-2
                         |
                         +---- PV-2
                                |
                                +---- EBS-2

And for networking:

    StatefulSet
         |
         +---- postgres-0
         +---- postgres-1
         +---- postgres-2
                    ^
                    |
             Headless Service
                    |
                    v
              Kubernetes DNS

For storage provisioning:

    PVC
      |
      v
    StorageClass
      |
      v
    EBS CSI Driver
      |
      v
    AWS EBS
      |
      v
    PV
      |
      v
    PVC becomes Bound
      |
      v
    Pod mounts storage

---

# 46. One Complete Example

Suppose we want to run three PostgreSQL replicas.

Requirements:

- 3 StatefulSet pods
- Stable identities
- One persistent disk per pod
- 20Gi per disk
- EBS storage
- RWO access
- Automatic storage provisioning
- Individual pod discovery

The conceptual architecture is:

    PostgreSQL StatefulSet
             |
             +---- postgres-0
             |        |
             |        +---- PVC-0
             |               |
             |               +---- EBS-0
             |
             +---- postgres-1
             |        |
             |        +---- PVC-1
             |               |
             |               +---- EBS-1
             |
             +---- postgres-2
                      |
                      +---- PVC-2
                             |
                             +---- EBS-2


    PostgreSQL StatefulSet
             |
             v
    Headless Service
             |
             v
       Kubernetes DNS

Storage provisioning:

    PVC
      |
      v
    StorageClass
      |
      v
    EBS CSI Driver
      |
      v
    EBS

---

# 47. Deployment vs StatefulSet — Quick Comparison

| Feature | Deployment | StatefulSet |
|---|---|---|
| Typical use | Stateless applications | Stateful applications |
| Pod identity | Interchangeable | Stable/predictable |
| Pod names | Random/generated suffixes | Predictable ordinal names |
| Example | backend API | PostgreSQL |
| Individual persistent storage | Not normally the main pattern | Common pattern |
| Ordered identity | No | Yes |
| Stable logical identity | No | Yes |
| `volumeClaimTemplates` | No | Yes |
| Individual pod discovery | Usually unnecessary | Often useful |
| Headless Service | Usually unnecessary | Commonly used |

---

# 48. PV vs PVC vs StorageClass vs CSI

These four concepts are easy to mix up.

## PV

    "Here is persistent storage available to Kubernetes."

PV = storage resource.

## PVC

    "I need persistent storage with these requirements."

PVC = storage request/claim.

## StorageClass

    "Here is how this type of storage should be dynamically provisioned."

StorageClass = provisioning configuration/blueprint.

## CSI Driver

    "I know how to communicate with the actual storage system."

CSI Driver = storage integration mechanism.

Therefore:

    PVC
      |
      v
    StorageClass
      |
      v
    CSI Driver
      |
      v
    Actual Storage
      |
      v
    PV
      |
      v
    PVC
      |
      v
    Pod

---

# 49. Static vs Dynamic — Final Mental Model

## Static

Think:

    "The disk already exists."

    EBS
      |
      v
    PV
      |
      v
    PVC
      |
      v
    Pod

Administrator prepares the storage.

## Dynamic

Think:

    "I need storage. Kubernetes, please provision it."

    PVC
      |
      v
    StorageClass
      |
      v
    CSI Driver
      |
      v
    EBS automatically created
      |
      v
    PV automatically created
      |
      v
    PVC bound
      |
      v
    Pod uses storage

---

# 50. Why Dynamic Provisioning + volumeClaimTemplates Is Powerful

Imagine a StatefulSet with:

    replicas: 100

Without `volumeClaimTemplates`, we would need to manually create and manage individual PVCs.

With `volumeClaimTemplates`:

    One PVC template
           |
           v
    100 StatefulSet replicas
           |
           v
    100 PVCs
           |
           v
    StorageClass
           |
           v
    EBS CSI Driver
           |
           v
    100 EBS volumes

This gives us automation at scale.

The important distinction is:

    We still have 100 PVCs.

But:

    We only define the PVC requirements once.

Kubernetes creates the individual claims for the StatefulSet replicas.

---

# 51. Practical Use Cases

## PostgreSQL

A PostgreSQL StatefulSet may require:

- Stable identity
- Persistent data
- Individual storage
- Database-specific networking/discovery

Conceptually:

    postgres-0 -> PVC-0 -> EBS-0
    postgres-1 -> PVC-1 -> EBS-1
    postgres-2 -> PVC-2 -> EBS-2

## Kafka

Kafka brokers have individual identities and persistent broker data.

StatefulSet can provide:

    kafka-0
    kafka-1
    kafka-2

with individual persistent storage.

## Elasticsearch

Elasticsearch nodes maintain persistent indexes/data.

StatefulSet can provide stable identities and persistent storage.

## Shared application files

If multiple application pods need access to the same filesystem:

    Pod 1
       |
    Pod 2 ----> EFS
       |
    Pod 3

EFS/RWX can be appropriate depending on application requirements.

---

# 52. What We Will Build in the Lab

The theory can now be tested using a small isolated Kubernetes lab.

We will NOT immediately modify the main production-style project.

The lab will demonstrate:

    StatefulSet
         |
         +---- Pod-0
         |       |
         |       +---- PVC-0
         |              |
         |              +---- EBS
         |
         +---- Pod-1
                 |
                 +---- PVC-1
                        |
                        +---- EBS

We will also use:

    StorageClass
        +
    EBS CSI Driver
        +
    Headless Service
        +
    volumeClaimTemplates

---

# 53. Lab Objectives

The lab should verify the following behavior:

1. Create a StorageClass.
2. Use the EBS CSI Driver.
3. Create a StatefulSet.
4. Create a Headless Service.
5. Use `volumeClaimTemplates`.
6. Deploy multiple StatefulSet replicas.
7. Verify that each pod gets its own PVC.
8. Verify that each PVC gets its own persistent volume/storage.
9. Write data into a pod's persistent volume.
10. Delete the pod.
11. Allow StatefulSet to recreate the same pod identity.
12. Verify that the existing PVC/storage is reused.
13. Verify that the data still exists.
14. Observe what happens when scaling the StatefulSet.
15. Understand the relationship between StatefulSet, PVC, PV, StorageClass, CSI, and EBS.

---

# 54. Final Mental Shortcut

Remember these simple definitions:

    Deployment
        =
    Interchangeable pods

    StatefulSet
        =
    Stable pod identity + stateful workload pattern

    Service
        =
    Stable network access to a group of pods

    Headless Service
        =
    Individual pod discovery through DNS

    PV
        =
    Persistent storage resource

    PVC
        =
    Request/claim for persistent storage

    StorageClass
        =
    Storage provisioning blueprint

    CSI Driver
        =
    Bridge/integration between Kubernetes and storage provider

    EBS
        =
    Persistent block disk

    EFS
        =
    Shared network filesystem

    RWO
        =
    ReadWriteOnce

    ROX
        =
    ReadOnlyMany

    RWX
        =
    ReadWriteMany

    Static provisioning
        =
    Storage already exists

    Dynamic provisioning
        =
    Kubernetes provisions storage automatically

    volumeClaimTemplates
        =
    Define PVC requirements once and automatically create individual PVCs for StatefulSet replicas

    Retain
        =
    Keep storage after the claim is released

    Delete
        =
    Allow dynamically provisioned storage to be automatically deleted as part of the PV lifecycle

---

# 55. The Complete Picture

The complete StatefulSet persistent-storage architecture can be remembered as:

    StatefulSet
        |
        +---- Stable Pod Identity
        |
        +---- volumeClaimTemplates
                    |
                    v
                  PVC
                    |
                    v
              StorageClass
                    |
                    v
              CSI Driver
                    |
                    v
                  EBS
                    |
                    v
                   PV
                    |
                    v
                  Data

And for networking:

    StatefulSet
        |
        +---- Pod-0
        +---- Pod-1
        +---- Pod-2
                 |
                 v
          Headless Service
                 |
                 v
         Individual DNS discovery

The overall principle is:

    StatefulSet
        =
    Stable identity

    PVC/PV
        =
    Persistent storage

    StorageClass + CSI
        =
    Automatic storage provisioning

    Headless Service
        =
    Individual pod discovery

Together, these components allow Kubernetes to run stateful workloads while separating:

    Application lifecycle
    from
    Storage lifecycle

That separation is the foundation of persistent state management in Kubernetes.