# Kubernetes Persistent Storage — Kind Practical Lab

## What We Practiced

We completed both:

- Static Provisioning
- Dynamic Provisioning

Cluster:

- Kind cluster: `stateful-lab`
- Workers:
  - `stateful-lab-worker`
  - `stateful-lab-worker2`

---

# 1. Static Provisioning

## Flow

Existing storage directory
→ PV
→ PVC
→ Pod

No StorageClass was used.

## 1. Create Static PV

`static-pv.yaml`

apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-demo-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/static-demo
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - stateful-lab-worker

Apply:

kubectl apply -f static-pv.yaml

Check:

kubectl get pv

Expected:

static-demo-pv → Available

---

## 2. Create Static PVC

`static-pvc.yaml`

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-demo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: static-demo-pv
  storageClassName: ""

Apply:

kubectl apply -f static-pvc.yaml

Check:

kubectl get pvc static-demo-pvc
kubectl get pv static-demo-pv

Expected:

PVC → Bound
PV  → Bound

---

## 3. Static PVC Troubleshooting

### Problem

Initially the PVC became:

Pending

because Kind automatically assigned its default StorageClass:

standard

The PV had no StorageClass.

### Fix

PVCs are immutable after creation for this field.

Delete the PVC:

kubectl delete pvc static-demo-pvc

Then explicitly set:

storageClassName: ""

and recreate:

kubectl apply -f static-pvc.yaml

Verify:

kubectl get pvc static-demo-pvc
kubectl get pv static-demo-pv

---

## 4. Create Pod Using Static PVC

`static-pod.yaml`

apiVersion: v1
kind: Pod
metadata:
  name: static-demo-pod
spec:
  containers:
    - name: app
      image: nginx:alpine
      volumeMounts:
        - name: static-storage
          mountPath: /data
  volumes:
    - name: static-storage
      persistentVolumeClaim:
        claimName: static-demo-pvc

Apply:

kubectl apply -f static-pod.yaml

Check:

kubectl get pod static-demo-pod

---

## 5. Test Static Storage

Write data:

kubectl exec static-demo-pod -- sh -c 'echo "Hello from static storage" > /data/test.txt'

Read data:

kubectl exec static-demo-pod -- cat /data/test.txt

Expected:

Hello from static storage

---

## 6. Test Persistence

Delete Pod:

kubectl delete pod static-demo-pod

Verify:

kubectl get pod

Verify storage still exists:

kubectl get pv static-demo-pv
kubectl get pvc static-demo-pvc

Expected:

PV  → Bound
PVC → Bound

Recreate Pod:

kubectl apply -f static-pod.yaml

Check:

kubectl get pod static-demo-pod

Read previous data:

kubectl exec static-demo-pod -- cat /data/test.txt

Expected:

Hello from static storage

This proves the data is stored in the persistent storage, not inside the Pod.

---

## 7. Static hostPath Troubleshooting

### Problem

After recreating the Pod, `test.txt` was initially missing.

Reason:

The Pod was scheduled on:

stateful-lab-worker2

But the actual hostPath data existed on:

stateful-lab-worker

Check Pod node:

kubectl get pod static-demo-pod -o wide

Check storage on workers:

docker exec stateful-lab-worker ls -la /mnt/static-demo

docker exec stateful-lab-worker2 ls -la /mnt/static-demo

The file existed on:

stateful-lab-worker

### Fix

Added PV node affinity:

nodeAffinity:
  required:
    nodeSelectorTerms:
      - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
              - stateful-lab-worker

This ensures the Pod uses the node where the static hostPath exists.

Check:

kubectl describe pv static-demo-pv

Look for:

Node Affinity

---

# 2. Dynamic Provisioning

## Flow

Existing StorageClass
→ PVC
→ Pod
→ Provisioner
→ Storage
→ PV
→ PVC Bound

In our Kind cluster, the StorageClass already existed.

We did NOT create it.

Check:

kubectl get storageclass

We had:

standard (default)

Provisioner:

rancher.io/local-path

Binding mode:

WaitForFirstConsumer

---

## 3. Create Dynamic PVC

`dynamic-pvc.yaml`

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-demo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi

Apply:

kubectl apply -f dynamic-pvc.yaml

Check:

kubectl get pvc dynamic-demo-pvc

Initially:

STATUS → Pending

This is expected because the StorageClass uses:

WaitForFirstConsumer

No Pod was consuming the PVC yet.

---

## 4. Create Dynamic Pod

`dynamic-pod.yaml`

apiVersion: v1
kind: Pod
metadata:
  name: dynamic-demo-pod
spec:
  containers:
    - name: app
      image: nginx:alpine
      volumeMounts:
        - name: dynamic-storage
          mountPath: /data
  volumes:
    - name: dynamic-storage
      persistentVolumeClaim:
        claimName: dynamic-demo-pvc

Apply:

kubectl apply -f dynamic-pod.yaml

Check:

kubectl get pod dynamic-demo-pod
kubectl get pvc dynamic-demo-pvc

After the Pod consumes the PVC:

PVC → Bound

A PV is automatically created.

---

## 5. Verify Automatically Created PV

kubectl get pv

The automatically created PV looked like:

pvc-0aa6186b-9bd8-4ea5-a628-77b60bbe75db

Check details:

kubectl describe pv pvc-0aa6186b-9bd8-4ea5-a628-77b60bbe75db

Important information:

StorageClass:
standard

Provisioner:
rancher.io/local-path

Selected node:
stateful-lab-worker2

Source:
HostPath

The local-path provisioner automatically created the storage directory and PV.

---

# Important Difference

## Static

Storage exists first.

We manually create:

PV
→ PVC
→ Pod

No StorageClass required.

## Dynamic

Storage does not exist first.

Existing StorageClass
→ PVC
→ Pod
→ Provisioner creates storage
→ PV automatically created
→ PVC becomes Bound
→ Pod uses storage

---

# Useful Verification Commands

kubectl get pv

kubectl get pvc

kubectl get pods

kubectl get pods -o wide

kubectl get storageclass

kubectl describe pv <pv-name>

kubectl describe pvc <pvc-name>

kubectl describe pod <pod-name>

kubectl exec <pod-name> -- cat /data/test.txt

kubectl delete pod <pod-name>

kubectl delete pvc <pvc-name>

kubectl delete pv <pv-name>

---

# Key Troubleshooting Lessons

1. PVC without `storageClassName` can automatically use the cluster's default StorageClass.

2. PVC `spec` is mostly immutable after creation. If the StorageClass is wrong, delete and recreate the PVC.

3. `storageClassName: ""` explicitly means the PVC should not use a StorageClass.

4. `WaitForFirstConsumer` can keep a PVC Pending until a Pod consumes it.

5. `hostPath` storage is node-local.

6. For static hostPath storage, use node affinity so the Pod runs on the node containing the storage.

7. Pod name does not provide persistence.

8. Headless Service is not required for persistence.

9. StatefulSet is not required for persistence.

10. Persistence comes from:

Pod
→ PVC
→ PV
→ actual storage

11. In dynamic provisioning, the application normally creates only the PVC. The provisioner automatically creates the storage and PV.

12. StorageClass is a Kubernetes resource. It is not the actual EBS/EFS storage.