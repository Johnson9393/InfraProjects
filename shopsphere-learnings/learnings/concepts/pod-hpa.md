# ShopSphere pods — Horizontal Pod Autoscaler (prod)

This note is **pod** autoscaling for **prod**. Dev does not get HPA. Dev still runs a fixed one replica.

The example throughout is the **order service**. Checkout creates an order. If one order pod dies, another must still take traffic. If a sale hits, we need more order pods without editing Helm by hand.

HPA scales **pods**. It does not add EC2 nodes. That is Cluster Autoscaler or Karpenter, a later step.

---

## What problem this solves

We already set prod to two replicas. That is a fixed floor. It does not grow.

Without HPA:

```text
Sale starts. CPU on both order pods is 90%.
Replica count stays 2.
Checkout gets slow or 5xx.
Someone edits values.yaml and syncs Argo.
```

With HPA:

```text
Sale starts. Average CPU > 70% or memory > 80%.
HPA raises order-service from 2 pods toward 4.
Sale ends. Metrics stay low for 5 minutes.
HPA removes one pod per minute, back toward 2.
```

Two pods is high availability (one pod can die). HPA is elasticity (load can grow). Both are production patterns. HPA does not replace the two-replica floor. `minReplicas: 2` is that floor.

---

## Real-time use case — order service

A customer places an order. Traffic goes ALB → API gateway → order-service → Aurora (and RabbitMQ for `order_created`).

At noon, 50 checkouts per minute. Two order pods, CPU about 30% of request. HPA does nothing. Count stays 2.

At 6pm, a campaign. CPU on those pods goes to 85% of the 50m request, or memory goes to 85% of 64Mi. HPA sees either metric over target. It adds pods, up to 4. The Service `order-service` load-balances across them. Aurora and Amazon MQ still handle the extra connections (RDS Proxy and MQ HA are separate).

Campaign ends. CPU drops. HPA **does not** immediately go back to 2. Scale-down waits 300 seconds, then removes at most one pod per minute. A 30-second dip does not flap 4 → 2 → 4.

If the node group is already full, the extra pods stay Pending until we add node autoscaling. That does not mean HPA failed. It means there is no machine to place the pod.

---

## Files in this story

| File | What it does |
|---|---|
| `shopsphere/helm/shopsphere/templates/hpa.yaml` | Creates one HPA per app Deployment when autoscaling is on |
| `shopsphere/helm/shopsphere/values.yaml` | Default: HPA off. Behavior, CPU, memory, min/max live here |
| `shopsphere/environments/prod/values.yaml` | `autoscaling.enabled: true` for prod |
| `shopsphere/helm/shopsphere/templates/order-service.yaml` (and the other seven Deployments) | Omit `spec.replicas` when HPA is on |
| `shopsphere-infra/infra/core-infra/cluster/addons.tf` | Metrics Server add-on. HPA reads CPU/memory from it |

The eight Deployments: product, user, cart, order, payment, notification, API gateway, frontend. Seed job has no HPA. It is a Job, not a long-running Deployment.

---

## Dev vs prod

| | Dev | Prod |
|---|---|---|
| `autoscaling.enabled` | `false` | `true` |
| Deployment `replicas` | Set (1) | Omitted |
| HPA object | Not created | One per service |
| Who owns pod count | Deployment | HPA (min 2, max 4) |

---

## Why we omit Deployment replicas in prod

HPA is a separate object. It is never a field inside the Deployment.

If GitOps keeps `replicas: 2` on the Deployment **and** an HPA, every Argo sync writes 2 again. HPA may have scaled to 3. Sync fights HPA.

Production GitOps:

- No HPA → Deployment `replicas` is source of truth (dev).
- HPA on → omit Deployment `replicas`. HPA min/max is source of truth (prod).

```yaml
# order-service.yaml (Deployment spec)
{{- if not .Values.autoscaling.enabled }}
replicas: {{ .Values.services.orderService.replicas }}
{{- end }}
```

**Dev** (`enabled` false): `not false` is true → Helm writes `replicas: 1`.

**Prod** (`enabled` true): `not true` is false → no `replicas:` line. HPA sets 2–4.

---

## The HPA template

File: `shopsphere/helm/shopsphere/templates/hpa.yaml`

Helm templates are **Go templates** plus Sprig (`list`, `dict`, `printf`). Not Groovy.

`$root := .` saves the full Helm context (values, release, chart). `.` is not a directory. Inside `range`, `.` becomes one list item, so we keep `$root` to read `minReplicas`.

`$fullName` comes from `_helpers.tpl` (`shopsphere.fullname`). For the prod Argo app the release is `shopsphere-prod`, so fullname is `shopsphere-prod`.

`$workloads` is a **list of maps**. Each map has `enabled` and `name`. The list is built first for all eight services. `enabled` is **not** checked while building the list.

`range` walks every item. Then `if $workload.enabled` decides whether to **emit** an HPA. If a service were disabled, we would not create an HPA pointing at a missing Deployment.

`---` is a YAML document splitter, not Helm logic. It sits **inside** the `if`. Each loop pass prints a new Kubernetes object in the same file. `{{-` on `if`/`range` only trims spaces.

Three `end`s, innermost first:

1. Close `if $workload.enabled`
2. Close `range`
3. Close `if autoscaling.enabled`

### Rendered order-service HPA (prod)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: shopsphere-prod-order-service
  namespace: shopsphere-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: shopsphere-prod-order-service
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      selectPolicy: Max
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
        - type: Percent
          value: 100
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      selectPolicy: Min
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
```

`scaleTargetRef` must match the Deployment name. Utilization is percent of **requests**, not limits. Order-service requests 50m CPU and 64Mi memory, so 70% CPU is 35m, 80% memory is about 51Mi.

When both metrics exist, Kubernetes takes the **higher** replica recommendation. High memory alone is enough to scale, which helps before pods sit near OOM. HPA cannot stop a sudden OOMKill inside one container.

---

## Behavior (scale-up / scale-down rules)

Without `behavior`, HPA still scales. Defaults can add a pod, remove it a minute later, then add it again (flapping).

`behavior` is **how fast**, not whether scaling exists.

### scaleUp

| Field | Value | Meaning |
|---|---|---|
| `stabilizationWindowSeconds` | `0` | Do not wait. React as soon as the metric is high |
| `policies` Pods `value: 2` | max +2 pods per 60s | |
| `policies` Percent `value: 100` | at most double per 60s | From 2 pods, +2 → 4 (already max) |
| `periodSeconds` | `60` | Window for those limits |
| `selectPolicy: Max` | Use the **larger** of the two policies | Scale up is allowed to be aggressive |

### scaleDown

| Field | Value | Meaning |
|---|---|---|
| `stabilizationWindowSeconds` | `300` | Wait 5 minutes of low CPU **and** memory before removing |
| `policies` Pods `value: 1` | Remove at most one pod per 60s | |
| `selectPolicy: Min` | Use the **gentlest** down policy | We only have one, so that one-pod rule |

Sale: 2 → 4 quickly. Quiet: 4 → 3 → 2 slowly.

Values live in `helm/shopsphere/values.yaml` and are repeated in `environments/prod/values.yaml`. The template uses `toYaml` on `autoscaling.behavior`.

---

## Metrics Server

HPA needs pod CPU and memory from the Metrics API. That is the EKS add-on `metrics-server` in `infra/core-infra/cluster/addons.tf`. Without it, HPA cannot see utilization and will not scale.

---

## What this is not

- **Not node scaling.** Cluster Autoscaler / Karpenter comes later. HPA is still real HPA without it.
- **Not custom metrics.** No RPS, no RabbitMQ queue depth. That needs Prometheus Adapter. Optional next layer.
- **Not a PodDisruptionBudget.** PDB is a separate object for drains.

For HPA alone, this is a production-grade first setup: min, max, CPU, memory, and behavior.

---

## Two sentences to remember

> **Replicas on the Deployment are a fixed count. HPA is a moving count with a floor and a ceiling.**

> **HPA adds and removes pods. Cluster Autoscaler adds and removes nodes so those pods have a place to run.**
