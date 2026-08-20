# EKS Worker Node Not Joining — Practical Troubleshooting

## Problem

```text
EKS Control Plane → Running ✅
EC2 Worker Node   → Running ✅
kubectl get nodes  → Node not showing ❌
```

**Important:** An EC2 instance being `Running` does not mean it has successfully joined the EKS cluster.

The troubleshooting goal is to find **which step of the node-joining process is failing**.

---

# 1. Check Kubelet

SSH/SSM into the worker node:

```bash
sudo systemctl status kubelet
```

Expected:

```text
Active: active (running)
```

If it is failed/stopped:

```bash
sudo systemctl restart kubelet
```

Then check:

```bash
sudo systemctl status kubelet
```

### Check kubelet logs

```bash
sudo journalctl -u kubelet -n 100 --no-pager
```

For live logs:

```bash
sudo journalctl -u kubelet -f
```

### Use case

If you see:

```text
connection timeout
Unauthorized
TLS error
authentication error
```

use that error to continue with the relevant troubleshooting below.

---

# 2. Check Node Bootstrap

When the EC2 instance starts, the EKS bootstrap process configures the node to join the cluster.

Check:

```bash
sudo cat /var/log/cloud-init-output.log
```

Look for:

```text
bootstrap failed
cluster not found
authentication failed
unable to connect
```

### Use case

If the node was configured with the wrong cluster name, endpoint, or bootstrap configuration:

```text
EC2 → Running ✅
EKS Node → Not Joined ❌
```

Correct the bootstrap/user-data configuration and recreate/restart the node as appropriate.

---

# 3. Check EKS Endpoint Connectivity

Get the EKS endpoint:

```bash
aws eks describe-cluster \
  --name <cluster-name> \
  --query 'cluster.endpoint'
```

From the worker node:

```bash
curl -vk https://<EKS-ENDPOINT>
```

### If it times out

Investigate:

```text
Route Table
NAT Gateway
VPC Endpoint
Security Group
Network ACL
DNS
```

### If it connects

The basic network path to the endpoint exists, so move to IAM/authentication checks.

---

# 4. Check Whether EKS Endpoint Is Public or Private

Run:

```bash
aws eks describe-cluster \
  --name <cluster-name> \
  --query 'cluster.resourcesVpcConfig.{Public:endpointPublicAccess,Private:endpointPrivateAccess}'
```

Example:

```text
Public: true
Private: false
```

or:

```text
Public: false
Private: true
```

## Private worker nodes + public EKS endpoint

The node generally needs outbound connectivity:

```text
Private Subnet
      ↓
NAT Gateway
      ↓
Internet Gateway
      ↓
EKS API Endpoint
```

Check the private subnet route table:

```text
0.0.0.0/0 → NAT Gateway
```

## Private EKS endpoint

The node communicates through the VPC/private path:

```text
Worker Node
     ↓
VPC
     ↓
Private EKS Endpoint
```

In this case, verify VPC DNS and internal networking.

---

# 5. Check Route Table

Find the route table associated with the worker-node subnet.

Conceptually, for a private subnet using NAT:

```text
Destination       Target

10.0.0.0/16       local
0.0.0.0/0         NAT Gateway
```

If the default route is missing:

```text
Worker Node
     ↓
Private Subnet
     ↓
❌ No route to EKS endpoint
```

The node may remain running but never join EKS.

---

# 6. Check Security Groups

Check the security groups attached to the worker node and EKS cluster.

```bash
aws ec2 describe-security-groups \
  --group-ids <sg-id>
```

Verify that the required node ↔ EKS communication is permitted.

Do **not** solve the problem by blindly adding:

```text
0.0.0.0/0
```

Allow only the required traffic between the appropriate resources/security groups.

### Use case

```text
Route exists ✅
Security Group blocks traffic ❌
Node cannot communicate with EKS
```

---

# 7. Check Network ACL

If routing and Security Groups look correct, check the subnet Network ACL:

```bash
aws ec2 describe-network-acls \
  --filters Name=vpc-id,Values=<vpc-id>
```

A Network ACL can still block traffic even when the Security Group allows it.

```text
Route          ✅
Security Group ✅
Network ACL    ❌
```

Result:

```text
Connection blocked
```

---

# 8. Check Worker Node IAM Role

Find the IAM role attached to the EC2 worker node and verify that it has the required EKS/node permissions.

Conceptually:

```text
EC2 Worker Node
      ↓
IAM Role
      ↓
AWS/EKS APIs
```

If required permissions are missing:

```text
EC2 Running       ✅
IAM Role          ✅
Required Policies ❌
Node Joining      ❌
```

If kubelet logs show:

```text
AccessDenied
```

investigate the node IAM role first.

Do not simply attach:

```text
AdministratorAccess
```

Instead, identify the specific missing permission.

---

# 9. Check EKS Authentication

The node's IAM role must also be recognized by EKS.

Depending on the EKS authentication configuration, this can be managed through **EKS access entries** or the older `aws-auth` mechanism.

The flow is:

```text
Worker Node IAM Role
        ↓
EKS Authentication
        ↓
Authorized?
   /          \
 YES           NO
  ↓             ↓
Join         Unauthorized
```

If logs show:

```text
Unauthorized
```

check the EKS authentication/access configuration.

---

# 10. Check Kubelet Authentication Errors

Run:

```bash
sudo journalctl -u kubelet -n 100 --no-pager
```

### Example 1 — Timeout

```text
connection timeout
```

Think:

```text
Network
 ↓
Route
 ↓
NAT/VPC Endpoint
 ↓
Security Group
 ↓
NACL
 ↓
DNS
```

### Example 2 — AccessDenied

```text
AccessDenied
```

Think:

```text
Node IAM Role
 ↓
Missing AWS permission
```

### Example 3 — Unauthorized

```text
Unauthorized
```

Think:

```text
EKS Authentication
 ↓
Node IAM Role not authorized
```

### Example 4 — Bootstrap error

```text
bootstrap failed
```

Think:

```text
User Data
 ↓
Cluster Name
 ↓
Cluster Endpoint
 ↓
Bootstrap Configuration
```

---

# 11. Useful Commands

### Check nodes from your workstation

```bash
kubectl get nodes
```

Detailed:

```bash
kubectl get nodes -o wide
```

---

### Check EKS cluster

```bash
aws eks describe-cluster \
  --name <cluster-name>
```

---

### Check EKS endpoint

```bash
aws eks describe-cluster \
  --name <cluster-name> \
  --query 'cluster.endpoint'
```

---

### Check endpoint access

```bash
aws eks describe-cluster \
  --name <cluster-name> \
  --query 'cluster.resourcesVpcConfig.{Public:endpointPublicAccess,Private:endpointPrivateAccess}'
```

---

### Check kubelet

```bash
sudo systemctl status kubelet
```

---

### Check kubelet logs

```bash
sudo journalctl -u kubelet -n 100 --no-pager
```

---

### Check bootstrap logs

```bash
sudo cat /var/log/cloud-init-output.log
```

---

### Test EKS API connectivity

```bash
curl -vk https://<EKS-ENDPOINT>
```

---

# 12. Practical Troubleshooting Flow

When:

```text
EKS Cluster → Running
EC2 Node    → Running
Node        → Not Joining
```

follow this order:

```text
1. kubectl get nodes
          ↓
2. Check kubelet
          ↓
3. Check kubelet logs
          ↓
4. Check bootstrap logs
          ↓
5. Test EKS endpoint connectivity
          ↓
6. Check route table
          ↓
7. Check NAT/VPC Endpoint
          ↓
8. Check Security Groups
          ↓
9. Check Network ACL
          ↓
10. Check Node IAM Role
          ↓
11. Check EKS Authentication
```

## Simple Mental Model

```text
EC2 starts
   ↓
Bootstrap runs
   ↓
Kubelet starts
   ↓
Node gets IAM credentials
   ↓
Node reaches EKS API
   ↓
EKS authenticates node
   ↓
Node registers
   ↓
kubectl get nodes
   ↓
Ready
```

**Troubleshooting principle:**

> **Don't assume the EC2 instance is the problem. Find which step in the node-registration path is failing.**
