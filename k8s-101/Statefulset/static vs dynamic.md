# Kubernetes Storage — Static vs Dynamic Provisioning

## Basic Terms

### EBS
EBS is basically a disk/storage volume in AWS.

Example:
AWS → EBS Volume → 10 GB disk

The disk exists in AWS, outside Kubernetes.

### PV — PersistentVolume
PV is a Kubernetes object that represents a storage volume.

Think:
" Kubernetes, this storage is available and can be used. "

### PVC — PersistentVolumeClaim
PVC is a request for storage.

Think:
" I need storage of this size and with these requirements. "

The PVC claims a suitable PV.

### CSI Driver
CSI Driver is the connection/communication layer between Kubernetes and the storage system.

For EBS:
Kubernetes → EBS CSI Driver → AWS EBS

The EBS CSI Driver knows how to work with EBS storage.

### StorageClass
StorageClass is a Kubernetes resource.

It contains rules about how storage should be provisioned.

Important:
StorageClass is NOT EBS.
StorageClass is NOT EFS.
StorageClass is a Kubernetes configuration that tells Kubernetes what kind of storage/provisioning should be used.

---

# 1. Static Provisioning

Static provisioning means:

> The actual storage already exists before Kubernetes asks for it.

Example with AWS EBS:

### Step 1 — Create EBS manually

We manually create an EBS volume in AWS.

Example:

AWS
→ EBS Volume
→ 10 GB

The EBS volume already exists.

### Step 2 — Install/configure EBS CSI Driver

We install the EBS CSI Driver so Kubernetes knows how to communicate with and manage EBS storage.

Think:

Kubernetes
→ EBS CSI Driver
→ AWS EBS

### Step 3 — Create PV manually

Now Kubernetes needs an object representing that existing EBS volume.

So we manually create a PersistentVolume (PV).

The PV references the existing EBS volume.

Think:

Existing EBS
→ PV represents that EBS storage inside Kubernetes

### Step 4 — Create PVC

We create a PVC.

The PVC says:

"I want this amount of storage."

The PVC claims the suitable PV.

So:

PV
→ PVC

### Step 5 — Pod uses the PVC

The Pod mounts the PVC.

The final flow is:

AWS EBS
→ PV
→ PVC
→ Pod

### Static Provisioning Summary

The important point is:

> Storage already exists, so we manually create the PV to represent that storage.

We manually do:

1. Create EBS
2. Create PV
3. Create PVC
4. Pod uses PVC

StorageClass is NOT required for this static flow.

---

# 2. Dynamic Provisioning

Dynamic provisioning means:

> We do NOT create the EBS volume manually. Kubernetes creates the storage when it is requested.

### Step 1 — Install/configure EBS CSI Driver

First, we install the EBS CSI Driver.

The CSI Driver knows how to communicate with AWS EBS.

Think:

Kubernetes
→ EBS CSI Driver
→ AWS EBS

### Step 2 — Create StorageClass

Now we create a StorageClass.

The StorageClass contains the rules for the storage we want.

For example, conceptually:

StorageClass
→ use EBS CSI Driver
→ create gp3 EBS
→ use certain storage settings

The StorageClass tells Kubernetes:

"Whenever somebody requests storage using me, use the EBS CSI Driver with these rules."

Important:

The CSI Driver does NOT create the StorageClass.

We create the StorageClass in Kubernetes.

The StorageClass simply tells Kubernetes which CSI Driver and storage rules to use.

### Step 3 — Create PVC

The application creates a PVC.

The PVC says:

"I need 10 GB of storage."

The PVC also refers to the StorageClass.

### Step 4 — CSI Driver creates EBS automatically

Kubernetes sees the PVC request.

The StorageClass tells Kubernetes to use the EBS CSI Driver.

The EBS CSI Driver then creates the EBS volume automatically in AWS.

So:

PVC
→ StorageClass
→ EBS CSI Driver
→ AWS EBS Volume

### Step 5 — PV is created automatically

Because the EBS volume was dynamically created, Kubernetes also creates a PV representing that EBS volume.

We do NOT manually create the PV.

So:

AWS EBS
→ automatically represented by PV

### Step 6 — Pod uses the PVC

The PVC becomes connected to the automatically created PV.

The Pod mounts the PVC.

Final flow:

StorageClass
→ PVC
→ EBS CSI Driver
→ EBS Volume
→ PV
→ PVC
→ Pod

---

# Static vs Dynamic — Simple Difference

## Static

Storage is already there.

We manually create everything needed to use it.

AWS EBS
→ manually created

PV
→ manually created

PVC
→ manually created

Pod
→ uses PVC

Simple idea:

> "Storage already exists. Kubernetes is told about it."

---

## Dynamic

Storage does not exist yet.

We ask Kubernetes for storage, and the storage is created automatically.

EBS CSI Driver
→ installed

StorageClass
→ created

PVC
→ created

EBS
→ automatically created

PV
→ automatically created

Pod
→ uses PVC

Simple idea:

> "I ask Kubernetes for storage, and Kubernetes creates the storage for me."

---

# The Most Important Difference

STATIC:

Existing EBS
→ PV
→ PVC
→ Pod

DYNAMIC:

StorageClass
→ PVC
→ CSI Driver
→ EBS automatically created
→ PV automatically created
→ Pod

Remember these two sentences:

> STATIC = Storage already exists → manually create PV.

> DYNAMIC = Storage doesn't exist → PVC + StorageClass + CSI Driver cause storage and PV to be created automatically.

# One Final Mental Model

Think of a restaurant.

### Static

The food is already prepared.

You tell the restaurant:

"This food already exists. Give me this food."

PV is basically Kubernetes' way of saying:

"This existing storage is available."

### Dynamic

You say:

"I want a pizza."

The restaurant prepares the pizza for you.

Similarly:

PVC says:

"I want storage."

StorageClass says:

"Use these storage rules."

CSI Driver knows how to communicate with AWS.

AWS EBS gets created automatically.

PV is automatically created to represent that storage.

The Pod then uses the PVC.

That is the difference between STATIC and DYNAMIC provisioning.