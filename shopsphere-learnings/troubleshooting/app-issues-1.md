# Troubleshoot issues 3 — ShopSphere GitOps lab (dev, Oct 21)

App was on the cluster. Argo was **Degraded**. This note is what we actually hit: probes, pod slots, image tags, Argo not watching `values.yaml`, frontend DNS, and seed wiping the catalog.

Related: `infra-pipeline-issues-1.md`, `infra-pipeline-issues-2.md`.

Repo: `InfraProjects` (app Helm + GitOps + Terraform in one Git repo). Namespace: `shopsphere-dev`. Shop: `https://shop.dev.infralabx.space`. API: `https://api.dev.infralabx.space`.

---

## How we started looking (commands)

```bash
kubectl get pods -n shopsphere-dev
kubectl describe pod <pod-name> -n shopsphere-dev
kubectl logs <pod-name> -n shopsphere-dev
kubectl get events -n shopsphere-dev --field-selector involvedObject.name=<pod-name>
```

`kubectl describe` has **no** `-o wide`. `-o wide` is for `get`.

```bash
kubectl get pods -n shopsphere-dev -o wide
```

Events are at the **bottom** of `describe`.

---

## 1. API gateway: `0/1 Running` vs Argo Degraded

**Issue**  
`kubectl get pods` showed `shopsphere-dev-api-gateway-…` **Running**. Argo health was **Degraded**. Nginx logs:

```
GET / HTTP/1.1" 404
"/etc/nginx/html/index.html" is not found
client: … user-agent: kube-probe/1.35
```

Describe Events:

```
Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 404
```

**Why**  
`Running` = container process is up. **`0/1 READY`** = kubelet probe failed, so the pod must not take traffic. Argo uses Ready.

**404 means kubelet did connect.** Nginx answered “that URL does not exist.” Connection refused / timeout would be a different Event.

Helm chart ConfigMap already had:

```nginx
location /health {
    return 200 "OK\n";
}
```

Chart values still probed `/`:

`shopsphere/helm/shopsphere/values.yaml` → `apiGateway.probes.readiness.path` / `liveness.path`.

**How we identified `/health`**  
Logs = kube hits `/`. Same chart’s nginx ConfigMap (`templates/api-gateway.yaml`) = `/health` returns 200. Values file = probe path `/`.

```bash
kubectl get configmap shopsphere-dev-api-gateway-config -n shopsphere-dev -o yaml | grep -A4 "location /health"
kubectl get deploy shopsphere-dev-api-gateway -n shopsphere-dev -o yaml | grep -A8 readinessProbe
```

**Fix**  
Set both probes to `/health` (port 80). Push Helm. Argo sync. Gateway becomes **1/1**.

Kubelet on the node runs probes. It tells **containerd** to pull/start. Events say “kubelet” because kubelet **reported** it. containerd is a **sibling** process, not inside kubelet. API server stores desired state; kubelet makes it real on that node.

---

## 2. Cart (and others): empty Argo logs, Pending, `Too many pods`

**Issue**  
Argo Logs for cart were **blank**. Describe:

```
Warning  FailedScheduling  0/3 nodes are available: 3 Too many pods
```

**Why**  
No container yet → no logs. Scheduler could not place the pod.

This is **pod count**, not disk/RAM. EKS `t3.medium` allocatable pods = **17** per node.

```bash
kubectl get pods -A --no-headers | wc -l
kubectl get nodes -o custom-columns=NAME:.metadata.name,PODS:.status.allocatable.pods
```

We had **55** pods and **3 × 17 = 51** seats. Extra pods stay Pending.

Cart Helm probes were already `/health`. Wrong tree to climb.

**Not this problem:** HPA (pod autoscaling) would add **more** pods. **Node** count (or Karpenter later) is the right class of fix. We did **not** add Karpenter in this lab.

**Fix**  
`shopsphere-infra/infra/core-infra/cluster/vars/dev.tfvars`: `desired_size` **3 → 4** (must sit between `min_size` 2 and `max_size` 5). Desired **6** would fail (above max). Desired **1** would fail (below min).

Node size is **Terraform**, not Argo. Push tfvars only, run **cluster** GitHub Action. Do **not** `kubectl apply` `root.yaml` again.

```bash
kubectl get nodes   # 4 Ready
```

Then Pending app pods schedule.

Monorepo: `git add` **only** the tfvars file first. Do not `git add .` (that would also push Helm probe / nginx). After nodes were Ready, we pushed `values.yaml` probe change separately.

---

## 3. Argo auto-sync looked idle; prune / selfHeal

Git already had:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Prune:** resource removed from Git → Argo deletes it on the cluster.  
**SelfHeal:** someone `kubectl edit`s live objects → Argo puts Git back.

Without a GitHub **webhook**, Argo **polls** (often ~3 minutes). **Refresh** fetches Git now. `root.yaml` is only for creating the parent app the first time.

Shop URL is the ALB/DNS (`shop.dev.infralabx.space`), not the Argo UI. Argo **Healthy** while a child pod is **Progressing 0/1** still means wait for **1/1** before trusting the browser.

---

## 4. Shop UI: “Failed to load products” (not empty seed)

**Issue**  
Shop page loaded. Red: **Failed to load products.**

**Why (UI)**  
That string is the **catch** path (API call failed). Empty catalog would be **No products found.**

```bash
kubectl logs job/shopsphere-dev-seed-job -n shopsphere-dev
# NotFound — Job already deleted (ttlSecondsAfterFinished / Helm hook cleanup)
```

```bash
curl -sS https://api.dev.infralabx.space/api/products
```

Curl returned **25 products**. Seed had worked. Direct **api.dev** skips frontend nginx.

Browser calls `shop.dev/api/products`. Frontend nginx (baked into the **image**) had:

```nginx
set $gateway api-gateway.ecommerce.svc.cluster.local;
```

Real Service: `api-gateway.shopsphere-dev.svc.cluster.local`. Kube-dns worked; the **name** was wrong. `resolver kube-dns.kube-system.svc.cluster.local` is in-cluster DNS.

**Lab fix**  
`shopsphere/app/frontend/nginx.conf`:

```nginx
set $gateway api-gateway.shopsphere-dev.svc.cluster.local;
```

That file is `COPY`’d in the frontend Dockerfile. **Pushing nginx.conf is not enough.** Rebuild frontend, new SHA in env values, Argo rolls the image.

**Prod-grade follow-up (not done this lab):** do **not** bake namespace into the image. Helm **ConfigMap** for frontend nginx (same idea as the gateway), namespace from values, **same image digest** for dev and prod.

---

## 5. CI: auto-write image SHA into `environments/dev/values.yaml`

**Wanted loop:** app change → build → ECR `${GITHUB_SHA}` → commit that SHA into Git → Argo sync.

`shopsphere-build.yaml` already built the matrix and tagged ECR. It did **not** update Helm values (we were pasting SHAs by hand).

**Add job** `update-dev-image-tags` (`needs: build`, `contents: write`):

- `APP_ENV=${{ inputs.environment || 'dev' }}` so the path is not hardcoded forever. Push-to-main still defaults **dev**.
- `sed` rewrite 40-char hex `tag: "…"` and `${APP_ENV}-shopsphere-seed:<sha>`.
- `git add` / `commit` / `push` that env file.

Path filter is `shopsphere/app/**`, so the bot commit to `environments/dev/values.yaml` does **not** rebuild.

Monorepo + matrix: **one commit SHA** tags **every** service. A frontend-only fix still rebuilds cart, gateway, etc. Simpler; slower. Per-folder builds = later.

**Do not push nginx until this job exists**, or ECR gets a new image and Argo keeps the old tag.

---

## 6. Build failed: ECR tag `buildcache` immutable

**Issue**

```
The image tag 'buildcache' already exists in the 'dev-shopsphere-frontend'
repository and cannot be overwritten because the tag is immutable.
```

**Why**  
App ECR is `image_tag_mutability = "IMMUTABLE"` (good for SHA tags). `--cache-to type=registry,…:buildcache` tries to **overwrite** the same tag.

**Do not** make the **app** repo mutable.

**Prod cache:** GitHub Actions cache, not ECR.

Build job: `actions: write`. Replace ECR cache lines with:

```yaml
--cache-from "type=gha,scope=${CACHE_SCOPE}" \
--cache-to "type=gha,mode=max,scope=${CACHE_SCOPE}" \
```

`scope` = `matrix.name` so frontend cache ≠ cart cache.

GHA cache speeds **CI builds only**. Argo does **not** use it. Faster deploy = SHA already in ECR + Git tag bump + auto-sync + enough nodes.

A **workflow-only** push does not start this workflow (`paths: shopsphere/app/**`). Use **Run workflow** (dev) after a cache-only change.

---

## 7. Values.yaml updated, pods did not roll

**Issue**  
Bot committed `fa8888ad…` into `environments/dev/values.yaml`. `kubectl get pods` AGE stayed old (except gateway from the earlier probe roll).

**Why**  
Argo Application was:

```yaml
source:
  path: shopsphere/helm/shopsphere
  helm:
    valueFiles:
      - ../../environments/dev/values.yaml
```

Helm **can** load that file at sync time. Argo **watches** only `path`. A commit that **only** changes `environments/dev/values.yaml` is invisible. Auto-sync never fires.

Hard **Refresh** on the app (once) did apply tags (pod AGE ~38m, images `fa8888ad…`). That is a lab poke, not the design.

**Prod fix:** two **sources** on the **same** repo (`shopsphere/gitops/apps/shopsphere-dev.yaml`).

```yaml
spec:
  sources:
    - repoURL: https://github.com/Johnson9393/InfraProjects.git
      targetRevision: main
      ref: values
    - repoURL: https://github.com/Johnson9393/InfraProjects.git
      targetRevision: main
      path: shopsphere/helm/shopsphere
      helm:
        valueFiles:
          - $values/shopsphere/environments/dev/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: shopsphere-dev
```

- `ref: values` = **nickname** of source 1 (the Git checkout). Not the filename.  
- `$values` = “that source’s repo root.”  
- `$values/shopsphere/environments/dev/values.yaml` = Argo’s `-f` for Helm.

Chart `helm/shopsphere/values.yaml` = defaults. Env file = **override** (`-f`). Templates use `.Values.apiGateway.image.tag` on the **merged** map. Git templates are **not** rewritten; Helm **renders** at sync.

**After pushing GitOps:** do **not** apply `root.yaml`. Parent **`shopsphere-app-of-apps`** watches `shopsphere/gitops/apps`. If parent revision is still the old SHA, Refresh **the parent** first so live `shopsphere-dev` gets `spec.sources`.

```bash
kubectl get application shopsphere-dev -n dev-argocd -o jsonpath='{.spec.sources}' ; echo
kubectl get application shopsphere-dev -n dev-argocd \
  -o jsonpath='sync={.status.sync.status} rev={.status.sync.revision}{"\n"}'
kubectl get deploy shopsphere-dev-frontend -n shopsphere-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

`grep '^  spec:'` on Application YAML matches **nothing** (`spec:` is column 0).

If Git SHA **already equals** live images, Argo stays **Synced**. That is success, not a missed rollout.

Prod tomorrow: **another** Application (`shopsphere-prod`), same chart, `$values/shopsphere/environments/prod/values.yaml`, namespace `shopsphere-prod`. Same SHA **promoted**, not a second rebuild.

Other real setups: `values-dev.yaml` **inside** the chart folder (one source, no `$values`). We kept `environments/`.

---

## 8. Seed Job emptied the shop (“No products found”)

**Issue**  
After the image roll, shop showed **No products found** (API **worked**, list empty). Seed pods `Error`. Logs: **Clearing existing products**, then **SKU already exists**, then exit because `total` was 0.

**Why**  
Hook was `post-install,post-upgrade`. **Every** Helm upgrade (Argo sync) re-ran seed. Script **DELETE**s products. Product API uses GORM **soft delete** (`deleted_at`). Unique SKU still blocks POST. Shop lists only non-deleted rows.

DB name is **`products`**, not `app`:

```bash
kubectl exec -n shopsphere-dev product-db-1 -- psql -U postgres -c '\l'
```

**Restore catalog**

```bash
kubectl delete job shopsphere-dev-seed-job -n shopsphere-dev
kubectl exec -n shopsphere-dev product-db-1 -- \
  psql -U postgres -d products -c "UPDATE products SET deleted_at = NULL;"
curl -sS 'https://api.dev.infralabx.space/api/products?page_size=1'
```

Expect `UPDATE 25` and `"total":25`. If you restore **without** deleting the Job, backoff retries wipe again.

**Stop it happening on the next sync**  
`shopsphere/helm/shopsphere/templates/seed-job.yaml`:

```yaml
"helm.sh/hook": post-install
```

(not `post-upgrade`). Push. Seed runs on **first install** only.

---

## Order that actually worked

1. Probe `/` → `/health` for gateway.  
2. Scale nodes 3 → 4 (Terraform cluster). Pending apps start.  
3. GHA cache instead of ECR `buildcache`; CI writes SHA into `environments/dev/values.yaml`.  
4. Frontend nginx → `shopsphere-dev` (image rebuild). ConfigMap = later.  
5. Argo two sources + `$values` so tag commits sync.  
6. Undelete products; seed hook `post-install` only.

---

## Quick command sheet

```bash
# Pods / events
kubectl get pods -n shopsphere-dev
kubectl describe pod <name> -n shopsphere-dev
kubectl get pods -A --no-headers | wc -l
kubectl get nodes -o custom-columns=NAME:.metadata.name,PODS:.status.allocatable.pods

# Images vs Git
kubectl get deploy -n shopsphere-dev \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# Argo
kubectl get application -n dev-argocd
kubectl get application shopsphere-dev -n dev-argocd -o jsonpath='{.spec.sources}{"\n"}'

# API / DB
curl -sS https://api.dev.infralabx.space/api/products
kubectl exec -n shopsphere-dev product-db-1 -- \
  psql -U postgres -d products -c "UPDATE products SET deleted_at = NULL;"
```
