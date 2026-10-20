# Infra issues — second lab (dev, Oct 20)

Second full dest run after the overnight destroy. Cluster came up. k8-services failed twice, then succeeded. App-infra was **not** applied; we destroyed again for a break.

Related notes from the first lab: `pipeline-issues.md`.

---

## 1. Loki Helm: `context deadline exceeded`

**Issue**  
k8-services apply died on `helm_release.loki`: Helm release created with failed status, then `context deadline exceeded`.

**Why**  
Helm `wait = true` (default) sits until every Loki/Promtail pod is Ready, then hits `timeout` (was 600s). Loki was slow (probes 503 while storage starts) and asked for **512Mi** on a cluster that already had Prometheus, Grafana, Argo, ESO, CNPG.

**Fix**  
Uninstall the failed release so the next apply can install cleanly. Give Helm more time and a smaller **request** (limit can stay higher).

```bash
aws eks update-kubeconfig --name dev-shopsphere --region us-east-1
helm uninstall loki -n dev-monitoring
```

In `k8-services/loki.tf`:

```hcl
timeout = 900
wait    = true

# loki.resources.requests
cpu    = "100m"
memory = "256Mi"
```

```bash
terraform fmt loki.tf   # CI runs fmt -check
```

Then **new Plan** (or Re-run **all jobs**). Do not Re-run Apply only — that still has the old `tfplan`.

---

## 2. Loki Pending: `Too many pods`

**Issue**  
After the Loki tweak, apply still could not Ready Loki:

```
0/2 nodes are available: 2 Too many pods
```

`loki-0` stayed Pending. Workflow would timeout again.

**Why**  
This is **not** RAM. Each EKS `t3.medium` allows **17 pods** (ENI/IP cap). Two nodes were at 17 and 16. No seat for Loki. kube-system + Argo + kube-prometheus-stack already filled the vans.

**Fix**  
Cancel the k8-services run. Uninstall Loki again if Helm still has it. Add a **third** node, then Plan k8-services again.

`cluster/vars/dev.tfvars`:

```hcl
eks_nodes = {
  application = {
    instance_type      = "t3.medium"
    desired_size       = 3
    min_size           = 2
    max_size           = 5
    kubernetes_version = "1.35"
  }
}
```

Cluster apply (scale, not a full rebuild). Then:

```bash
kubectl get nodes   # expect 3 Ready
```

New k8-services apply (Plan + Apply).

---

## 3. State lock after cancelling Apply

**Issue**  
New k8-services **Plan** failed:

```
Error acquiring the state lock
Path: shopsphere-terraform-state009/dev/core-infra/k8-services/terraform.tfstate
Operation: OperationTypeApply
Who: runner@...
```

**Why**  
Cancel in GitHub kills the runner. Terraform does **not** always drop the S3 lock. The next Plan sees “someone is still applying.”

**Fix**  
Do **not** start a third workflow. Do **not** `-lock=false`. Unlock that id, then Re-run **failed jobs** on the Plan that just failed.

Laptop: AWS CLI SSO can work while Terraform uses a **dead static key**. Export the SSO session first:

```bash
cd shopsphere-infra/infra/core-infra/k8-services

eval "$(aws configure export-credentials --format env)"
export AWS_REGION=us-east-1
aws sts get-caller-identity

terraform init -backend-config=vars/dev.tfbackend
terraform force-unlock 741ea92a-3a5f-debd-97d4-f860f32262f8
# type yes
```

Use the lock **ID from your error**, not this one, if it happens again.

If `terraform init` says `InvalidClientTokenId` but `aws sts` is fine: you skipped `eval "$(aws configure export-credentials --format env)"` in that same shell.

---

## 4. Re-run Plan vs Re-run Apply (workflow)

On `main` we now checkout `ref: main` and upload the plan with `overwrite: true`.

| What failed | What to Re-run | Why |
|-------------|----------------|-----|
| Plan (fmt, lock, validate) | Failed jobs (Plan). Apply starts after Plan is green. | New `tfplan`, overwrite artifact. |
| Apply, **no** code change | Apply only | Same reviewed plan (AWS flake). |
| Apply, **you changed** `.tf` | All jobs / Plan then Apply | Old `tfplan` does not contain Loki timeout or node count. |

Do not Re-run Apply only after a Loki/tfvars fix.

---

## What worked this round

- Cluster with **3× `t3.medium`**.
- k8-services green after unlock + Loki install.
- App-infra **not** run. Destroy from the GitHub workflow (`action: destroy`) for the break. OIDC + S3 state bucket stay.

Next session: cluster (3 nodes already in tfvars) → k8-services → app-infra. Dummy Razorpay repo secrets before app-infra if they are still empty.
