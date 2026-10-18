# Pipeline issues — ShopSphere first real apply

This is a lab diary from the first time we applied **cluster** and **k8-services** for real (Oct 18–19, 2026), plus the **app-infra** fixes we made *before* that stack ran, so tomorrow’s apply does not hit the same class of bugs.

Stacks (GitHub workflow `shopsphere-infra.yaml`, `workflow_dispatch` only):

1. `shopsphere-infra/infra/core-infra/cluster`
2. `shopsphere-infra/infra/core-infra/k8-services`
3. `shopsphere-infra/infra/app-infra` (not applied yet on this run)

**Apply order:** cluster → k8-services → app-infra.  
**Destroy order:** app-infra → k8-services → cluster. Destroy ignores `infra_path`. It does **not** delete the S3 state bucket or GitHub OIDC.

**Do not “Re-run failed jobs”** after you change Terraform. That reuses the old SHA and the old `tfplan`. After a code fix: commit, push, **new** workflow_dispatch.

We did **not** add a pre-commit hook. We started one, then deleted `.githooks` so a mid-lab fix commit would not mix hook files into the repo. Hardening later.

---

## How to read each issue

For every item: what broke (or would break), why, what we did, and the code that stayed in the repo.

---

# Cluster

## 1. EKS access policy raced the access entry

**What happened**  
`aws_eks_access_policy_association` was created in the same apply as `aws_eks_access_entry`. AWS sometimes tried to attach the admin policy before the entry existed.

**Why**  
Two separate resources. Terraform only waits if there is a reference (or `depends_on`) from the association to the entry.

**Fix**  
The association must read the entry, not only `var.cluster_admin_role_arns`. That creates an implicit dependency.

```hcl
# modules/eks/eks.tf
resource "aws_eks_access_policy_association" "cluster_admins" {
  for_each = toset(var.cluster_admin_role_arns)

  cluster_name  = aws_eks_access_entry.cluster_admins[each.value].cluster_name
  principal_arn = aws_eks_access_entry.cluster_admins[each.value].principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
```

SSO admin ARN in tfvars was already correct. After this, **cluster apply succeeded**.

---

## 2. Nodes were too small (`t3.small` × 2)

**What happened**  
Cluster itself applied. Later, k8-services Helm (Argo CD + kube-prometheus-stack) hit `context deadline exceeded`. We checked Pending **after** those charts were gone and saw nothing Pending — that was misleading. While Helm was waiting, pods could not get Ready on 2× `t3.small`.

**Why**  
A `t3.small` has about **1.4 GiB allocatable**. One node was already ~half used by kube-system, ALB controller, ESO, CNPG. Prometheus was asking for **1 GiB**, Grafana **512 Mi**, plus Argo. Helm `wait = true` means: all pods Ready, or timeout. Timeout is a symptom. The cause is **RAM**.

`kubectl get pods -A --field-selector=status.phase=Pending` after a failed Helm uninstall shows a healthy empty cluster. Look at nodes **during** the wait, or `kubectl describe nodes` Allocated resources.

**Fix**  
We do **not** need three nodes for the platform stack. We need **bigger** nodes. Same count (2), `t3.medium` (4 GiB). `max_size = 5` so we can add a third later when the ShopSphere app + four Postgres clusters go Pending.

```hcl
# infra/core-infra/cluster/vars/dev.tfvars
eks_nodes = {
  application = {
    instance_type      = "t3.medium"
    desired_size       = 2
    min_size           = 2
    max_size           = 5
    kubernetes_version = "1.35"
  }
}
```

Changing instance type **replaces** the node group (destroy smalls, create mediums). Logs look like `Still destroying...` for 10–20 minutes. **Do not cancel.** Control plane stays up; workers come back.

Also reduced Prometheus/Grafana **requests** in k8-services so the lab fits next to Argo (see k8-services §5).

---

# k8-services

## 3. `terraform fmt -check` failed in CI

**What happened**  
Plan job failed with `terraform fmt -check` exit 3. CI does **not** auto-format. It only checks.

**Why**  
Someone (or an editor) saved `.tf` with different alignment. GitHub Actions runs `fmt -check -recursive` on the stack path.

**Fix**  
Locally: `terraform fmt -recursive` in that stack, commit, push, **new** run. Do not Re-run failed jobs.

---

## 4. ACM validation had no `count` (Unexpected resource instance key)

**What happened**  
`aws_acm_certificate.env` has `count` (only on the platform env, `dev`). Locals and Ingress used `.env[0]`. `aws_acm_certificate_validation.env` originally had **no** `count`, so Terraform treated it as a single instance while everything else expected `[0]`.

**Fix**

```hcl
# infra/core-infra/k8-services/acm.tf
resource "aws_acm_certificate_validation" "env" {
  count           = local.deploy_acm ? 1 : 0
  certificate_arn = aws_acm_certificate.env[0].arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation :
    record.fqdn
  ]
}
```

Then `terraform fmt` again (alignment). Fresh k8-services apply.

---

## 5. ALB mutating webhook race (ESO / Argo / Prometheus)

**What happened**

```
failed calling webhook "mservice.elbv2.k8s.aws":
no endpoints available for service "aws-load-balancer-webhook-service"

Helm release "argocd" ... context deadline exceeded
helm_release.kube_prometheus_grafana_stack ... context deadline exceeded
```

**Why**  
Helm installs the AWS Load Balancer Controller and registers a **mutating webhook on Services** immediately. The controller **pod is not Ready yet** (no Endpoints). Terraform then installs ESO, Argo, Prometheus **in parallel**. Those charts create Services → admission webhook → nobody listening → ESO fails. Argo/Prometheus wait until Helm timeout.

`helm_release.aws_load_balancer_controller` had no `wait`. Other charts did not `depends_on` it.

**Fix**  
Sleep 60s after the ALB chart, and make ESO / Argo / Prometheus / CNPG wait on that sleep. Argo timeout 600s. Slimmer Prometheus/Grafana requests (lab).

```hcl
# alb-controller.tf
resource "time_sleep" "wait_alb_webhook" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "60s"
}
```

```hcl
# eso.tf / argocd.tf / monitoring.tf / cnpg.tf
depends_on = [time_sleep.wait_alb_webhook]
```

```hcl
# argocd.tf
wait    = true
timeout = 600
```

```hcl
# monitoring.tf (lab requests)
prometheusSpec.resources.requests = { cpu = "100m", memory = "400Mi" }
grafana.resources.requests        = { cpu = "50m",  memory = "128Mi" }
timeout = 900
```

`hashicorp/time` is declared in `k8-services/versions.tf`.

This was **not** a bad Argo/ESO chart. It was ordering.

---

## 6. Helm “cannot re-use a name that is still in use”

**What happened**  
After the webhook failure we applied again:

```
cannot re-use a name that is still in use
```

on `argocd`, `eso`, `kube-prometheus-stack`.

**Why**  
The first apply **did** install Helm releases in the cluster. Terraform **did not** save them in state (apply failed). Next apply tries `helm install` again. Helm still has those names.

**Fix**  
Do **not** destroy the whole stack. Uninstall only the leftovers, then new apply. Leave ALB controller and CNPG if Terraform already owns them.

```bash
aws eks update-kubeconfig --name dev-shopsphere --region us-east-1

helm uninstall argocd -n dev-argocd
helm uninstall eso -n dev-eso
helm uninstall kube-prometheus-stack -n dev-monitoring

helm list -A
```

Argo CRDs may stay (`resource-policy: keep`). Next install reuses them. That is normal.

If k8-services fails again the same way, uninstall those three **again** before the next apply.

---

## 7. Helm wait timeout after the webhook was already fixed

**What happened**  
Next apply: ESO succeeded (webhook race gone). Argo and kube-prometheus-stack still `context deadline exceeded`. “Helm release created but has a failed status.”

**Why**  
`wait = true` + pods never Ready. Root cause was **§2 node size**, not another webhook bug. After failure, Helm leftovers disappear if you uninstall (or the release is failed). `kubectl get pods --field-selector=status.phase=Pending` then shows nothing.

**Fix**  
Resize nodes (**cluster apply first**), then new k8-services apply. Uninstall leftover Argo/Prometheus if Helm still has the names. After `t3.medium` × 2, those charts went Ready and k8-services **succeeded**.

---

## 8. Route53 read Ingress status before the ALB hostname existed

**What happened**  
Helm/Ingress were fine. Apply died on DNS:

```
kubernetes_ingress_v1.argocd_ingress_tls[0].status[0].load_balancer[0].ingress is empty list of object
```

Same for Grafana and Prometheus.

**Why**  
`kubernetes_ingress_v1` is created **before** the ALB controller writes ADDRESS. Terraform freezes `.status` at create time (empty). `time_sleep` + `depends_on` does **not** refresh those attributes. Route53 then indexes `[0]` on an empty list.

We checked **live AWS** — the ALB was already correct:

| Piece | Value |
|--------|--------|
| Group | `shopsphere-shared-alb` |
| DNS | `k8s-shopsphereshareda-d1134abaeb-….us-east-1.elb.amazonaws.com` |
| Zone ID | `Z35SXDOTRQ7X7K` (us-east-1 ALB) |
| Tags | `Name=shopsphere-ingress`, `ManagedBy=Terraform` |
| IngressClass | `alb` |

So this was **not** a wrong group name or wrong zone ID. It was Terraform reading too early.

**Fix**

1. `wait_for_load_balancer = true` on Argo/Grafana/Prometheus Ingress (wait until ADDRESS exists, timeout 10m).
2. `data.kubernetes_ingress_v1` **after** that — re-read hostname from the live object.
3. `data.aws_lb` by tags for the real ALB **zone_id**.

File: `infra/core-infra/k8-services/ingress-dns.tf`.

```hcl
# On each platform ingress (argocd.tf / monitoring-ingress.tf)
wait_for_load_balancer = true

timeouts {
  create = "10m"
  delete = "10m"
}
```

```hcl
# ingress-dns.tf (idea)
data "kubernetes_ingress_v1" "argocd" {
  count = local.deploy_argocd ? 1 : 0
  metadata {
    name      = kubernetes_ingress_v1.argocd_ingress_tls[0].metadata[0].name
    namespace = kubernetes_ingress_v1.argocd_ingress_tls[0].metadata[0].namespace
  }
  depends_on = [kubernetes_ingress_v1.argocd_ingress_tls]
}

data "aws_lb" "shared_ingress" {
  tags = {
    Name      = "${var.app_subdomain}-ingress"
    ManagedBy = "Terraform"
  }
}

resource "aws_route53_record" "argocd" {
  # ...
  alias {
    name                   = data.kubernetes_ingress_v1.argocd[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.shared_ingress[0].zone_id
    evaluate_target_health = true
  }
}
```

After this, k8-services apply **succeeded**. Then we started **destroy** so overnight cost (EKS + nodes + NAT + ALB) goes away. Tomorrow: cluster → k8-services → app-infra, fresh.

---

# App-infra (fixed ahead of the first apply)

These did **not** fail in CI yet. We changed them so the first app-infra apply is less likely to die the same way. **Cluster and k8-services files were not touched** for this part.

App-infra does **not** Helm-install ShopSphere. Argo does that later. Terraform here: namespace, Secrets Manager, ESO ExternalSecrets, CNPG Clusters, Redis, RabbitMQ, Ingress for shop/api, Route53.

---

## 9. Ingress waited for ALB while app Services did not exist

**What would happen**  
Ingress backends are Services `frontend` and `api-gateway` in `shopsphere-dev`. Those Services appear when Argo syncs the chart. `wait_for_load_balancer = true` can sit 10 minutes and fail on a first apply.

**Fix**  
Do not wait. Write the Ingress (same shared ALB group/tags as k8-services). The controller attaches hosts when it can. Until Argo exists, `shop.` / `api.` may not serve the app. That is OK.

```hcl
# infra/app-infra/ingress.tf
# App Services (frontend, api-gateway) are created later by Argo CD.
wait_for_load_balancer = false
```

We did **not** create dummy Services. Helm would fight them later (`cannot re-use a name`).

---

## 10. App Route53 used empty Ingress status

**What would happen**  
Same bug as §8: sleep, then `.status.load_balancer.ingress[0].hostname`. First apply: empty list, Invalid index.

**Fix**  
The shared ALB **already exists** after k8-services (same tags). Alias shop/api to **that** ALB DNS and zone from `data.aws_lb`. No Kubernetes status.

`evaluate_target_health = false` so Route53 does not require healthy targets before the app exists.

```hcl
# infra/app-infra/route53.tf
data "aws_lb" "ingress" {
  count = length(local.ingress_services) > 0 ? 1 : 0

  tags = {
    Name      = "${var.app_subdomain}-ingress"
    ManagedBy = "Terraform"
  }
}

resource "aws_route53_record" "service" {
  for_each = local.ingress_services

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.host
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress[0].dns_name
    zone_id                = data.aws_lb.ingress[0].zone_id
    evaluate_target_health = false
  }

  depends_on = [kubernetes_ingress_v1.service]
}
```

Prerequisite: k8-services **green** first, or `data.aws_lb` finds nothing.

---

## 11. ExternalSecrets started before Secrets Manager had a version

**What would happen**  
ESO tickets were created as soon as the namespace + ClusterSecretStore existed. They did not wait for `aws_secretsmanager_secret_version`. ESO can reconcile, miss the AWS secret, and never write the Kubernetes Secret in time.

**Fix**

```hcl
# infra/app-infra/eso.tf
depends_on = [
  kubernetes_namespace_v1.shopsphere,
  kubernetes_manifest.cluster_secret_store,
  aws_secretsmanager_secret_version.shopsphere,
]
```

---

## 12. ESO sync wait was 45s and only when CNPG was on

**What would happen**  
Terraform then `data.kubernetes_secret_v1` for product-db, redis, rabbitmq, etc. First ESO sync (Pod Identity + AWS) is often slower than 45s → `secrets "…-credentials" not found`. The sleep `count` was only if CNPG clusters existed. Redis/RabbitMQ hung off that sleep; if CNPG were off, they barely waited.

**Fix**  
180s whenever ESO is enabled. Sleep also waits on secret versions.

```hcl
# infra/app-infra/databases.tf
resource "time_sleep" "wait_for_cnpg_credentials" {
  count = var.enable_eso_secrets ? 1 : 0

  create_duration = "180s"

  depends_on = [
    kubernetes_manifest.external_secrets,
    aws_secretsmanager_secret_version.shopsphere,
  ]
}
```

CNPG, Redis, and RabbitMQ data sources still `depends_on` this sleep. It is still a sleep, not a “wait until Secret exists” loop — but 45s was the race we could predict.

---

## 13. Redis Deployment blocked the whole apply on Ready

**What would happen**  
`kubernetes_deployment_v1.redis` defaults to `wait_for_rollout = true`. RabbitMQ is a raw manifest and does **not** wait. If Redis is Pending (scheduling next to four CNPG clusters), apply fails even though the Deployment was created.

**Fix**

```hcl
# infra/app-infra/databases.tf — on kubernetes_deployment_v1.redis
wait_for_rollout = false
```

The Secret must still exist (the 180s wait), or the pod CrashLoops on a missing password. Terraform just will not sit on Ready.

---

# Operating rules we learned

1. After **code** change: new workflow_dispatch. Never Re-run failed jobs for a new SHA.
2. After a **failed Helm create**: `helm list -A`, uninstall names Terraform does not own, then apply again.
3. Node type change = node group **replace**. Let destroy/create finish.
4. Destroy overnight: workflow `action: destroy`. Keeps OIDC + state bucket.
5. Tomorrow: cluster → k8-services → app-infra → **then** build images → paste SHA into values → Argo (`gitops/root.yaml` only).
6. App-infra needs GitHub **repo** secrets: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, and `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (mapped to `TF_VAR_*` in the workflow). Placeholders are OK for the lab.
7. k8-services must be green before app-infra: ACM `*.dev.infralabx.space` ISSUED, shared ALB tagged, ESO + CNPG operators installed.

---

# What we did not fix yet (not apply-blockers for the path above)

- Pre-commit hook for `fmt` + `validate` (deferred).
- EKS API `0.0.0.0/0` — jump host later.
- Notification service static AWS keys in pods — Pod Identity later.
- `kubernetes.io/cluster/<name>` subnet tags — ALB worked with `vpcId` on the controller; optional hardening.
- CoreDNS vs node-group race on a **brand-new** cluster — tonight’s cluster apply succeeded; watch if a full recreate DEGRADES CoreDNS.
- Three nodes when the app + four Postgres go Pending — bump `desired_size`, do not guess now.
- ApplicationSet / prod promotion — later.

---

# Live facts from this lab (account `023192525105`, `us-east-1`)

- Cluster name: `dev-shopsphere`
- Domain: `infralabx.space`
- Shared ALB group: `shopsphere-shared-alb`
- ALB Name tag: `shopsphere-ingress`
- State bucket (keep): `shopsphere-terraform-state009`
- Namespaces we used: `dev-argocd`, `dev-eso`, `dev-monitoring`, `dev-cnpg-system`; app will be `shopsphere-dev`
