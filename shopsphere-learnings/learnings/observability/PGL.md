# ShopSphere — Observability (Prometheus, Grafana, Loki)

This note is what we **actually installed** on EKS in `k8-services`, why it exists next to CloudWatch, and how to talk about it in an interview. Files:

- `shopsphere-infra/infra/core-infra/k8-services/monitoring.tf`
- `shopsphere-infra/infra/core-infra/k8-services/monitoring-ingress.tf`
- `shopsphere-infra/infra/core-infra/k8-services/ingress-dns.tf`
- `shopsphere-infra/infra/core-infra/k8-services/loki.tf`

Namespace: **`dev-monitoring`** or **`prod-monitoring`**. Shop apps stay in **`shopsphere-dev`** / **`shopsphere-prod`**.

Public URLs (ALB + ACM `*.<env>.infralabx.space`):

- Grafana: `https://grafana.dev.infralabx.space` / `https://grafana.prod.infralabx.space`
- Prometheus: `https://prometheus.dev.infralabx.space` / `https://prometheus.prod.infralabx.space`
- Loki: **no public URL**. Grafana talks to it inside the cluster.

---

## 1. What we are solving

ShopSphere runs as many pods (gateway, cart, product, nodes, Argo). When something is wrong you need:

- **Numbers over time:** CPU, memory, pod Pending, restarts, later HTTP 500 **counts**.
- **Log lines:** nginx 404, cart stack traces, seed “SKU already exists”.
- **A screen** that shows both, like the ECS CloudWatch dashboard in `terraform-ecs-3tier-deployment/infra/dashboard.tf`.

| Job | AWS (your ECS lab) | This EKS lab |
|---|---|---|
| Numbers | CloudWatch **Metrics** | **Prometheus** |
| Pretty graphs | CloudWatch **Dashboard** | **Grafana** |
| Log text | CloudWatch **Logs** (+ Fluent Bit or `awslogs`) | **Loki** (+ **Promtail**) |

Prometheus does **not** store log files. Loki does **not** store CPU graphs. Grafana **reads** both.

Day to day you open **Grafana**. Prometheus UI is the engine room (raw queries, target list). Loki has no website here.

---

## 2. Prometheus — what it is and why ShopSphere uses it

**What it is:** a server that **goes out on a timer**, **reads number pages** from targets, and **stores** those numbers on disk (your 15 days / size cap).

**What it is not:** not in the shop HTTP path. Add-to-cart still goes browser → ALB → frontend → api-gateway → cart-service. Prometheus is not in that hop.

**Why we use it on EKS:** kube-prometheus-stack, node-exporter, kube-state-metrics, and grafana.com dashboards **7249** / **6417** are built for **Kubernetes** (nodes, pods, Pending, restarts). That language matches the cluster. CloudWatch can do EKS too (Container Insights); this stack is the usual **in-cluster, Kubernetes-first** choice.

### What we install

Helm chart **`kube-prometheus-stack`** (v70) into `*-monitoring`. That creates **real pods**:

- **Prometheus server** — stores numbers, 20Gi volume.
- **Grafana** — dashboards (same chart).
- **Prometheus Operator** — a helper pod that applies “tickets” (ServiceMonitor / PodMonitor).
- **node-exporter** — **DaemonSet**: one pod **per node**. Node CPU, memory, disk.
- **kube-state-metrics** — usually **one** Deployment. Reads the API: pod Running/Pending, restarts, replica counts. **Includes ShopSphere pods** as Kubernetes objects.
- **Alertmanager** — chart default; we did not wire Slack/email.

`count = local.deploy_monitoring ? 1 : 0` — install when monitoring is on. **Dev** gets it because `platform_env` defaults to `dev`. **Prod** gets it because `enable_monitoring = true` and `platform_env = "prod"`. Two clusters, two copies.

### Prometheus settings in `monitoring.tf` (what we wrote)

**Requests / limits** — Prometheus pod itself: 100m/400Mi request, 500m/1Gi limit, so it does not eat a whole `t3.medium`.

**`retention = "15d"`** and **`retentionSize = "10GB"`** — keep numbers 15 days or until ~10GB, then drop old points.

**`serviceMonitorSelector` / `serviceMonitorNamespaceSelector` / `podMonitor*` all `{ }`**

These do **not** mean “watch every Kubernetes Service in the cluster” and they do **not** list cart/product.

A **ServiceMonitor** is a **ticket**: “Prometheus, also read numbers from **this** Service, this port, this path.” A **PodMonitor** is the same idea aimed at **pods** instead of a Service.

The two ServiceMonitor fields on Prometheus mean:

1. Which **tickets** to accept (labels on the ServiceMonitor object).
2. In which **namespaces** to look for those ticket objects.

`{ }` = **do not filter tickets**. Accept every ServiceMonitor/PodMonitor that exists.

**Today** those tickets come from **kube-prometheus-stack**: cluster health (nodes, kubelet, kube-state, …). **ShopSphere API counters** (`http_requests_total` on cart `/metrics`) need **extra tickets you write**. Until then:

- **Yes:** CPU/memory of the **cart pod**, Pending, restarts (cluster view of that pod).
- **No:** cart HTTP 500 **count** from the app’s `/metrics` page.

If you later add a cart ServiceMonitor, `{ }` will **also** accept that ticket unless you tighten labels. Empty was chosen so the **chart’s cluster tickets keep working** with no extra label matching.

**`additionalScrapeConfigs = []`** — optional **hand-typed list of URLs** in Terraform. Empty = no extra IPs. Do **not** hardcode `cart-service.shopsphere-dev.svc…` here for real; use ServiceMonitors so **dev/prod namespace** stays in Helm.

**`externalUrl`** — Prometheus’s **own** public name (`https://prometheus.<env>.infralabx.space`) for **links inside the Prometheus UI**. It does not create the ALB. Ingress does.

**`routePrefix = "/"`** — UI at the hostname root, matching Ingress path `/`.

**`storageSpec` 20Gi, `ReadWriteOnce`, StorageClass `gp3`** — EBS disk so Prometheus can restart without wiping metrics. **gp3** is an EBS SSD type (newer than **gp2**). Not EFS. Need a StorageClass named `gp3` on the cluster.

**`service` ClusterIP port 9090** — stable in-cluster name for Grafana. Same idea as `cart-service:8003`. The internet uses the Ingress, not 9090 directly.

**`nodeExporter.enabled` / `kubeStateMetrics.enabled`** — turn those collectors on.

**`defaultRules.create = true`** — chart **alert/recording rules** (node not ready, crash loop, …). That is **when to treat numbers as a problem**, not a new data pipe. Paging (Slack) is not wired.

### Prometheus UI vs Grafana

Prometheus UI: type a query, see **Targets**, debug the engine.  
Grafana: **saved dashboards** (your CloudWatch `dashboard.tf`).

---

## 3. Grafana — what it is and why we added it

**What it is:** the **website** you open. Datasources point at Prometheus and Loki. Dashboards draw graphs.

**Why:** operators should not type PromQL for every incident. Same reason you built `dashboard.tf` for ECS: one screen for compute, traffic, errors.

### What we wrote

**`enabled = true`**, admin password in Terraform (lab only; not a prod secret pattern).

**Grafana disk 10Gi gp3** — saved dashboards/settings survive pod restart.

**Grafana Service ClusterIP port 80** — Ingress sends HTTPS to this.

**Sidecar (datasources)** — **not** a second pod. Extra **container in the Grafana pod**. It **loads datasource config**. It does **not** copy cluster numbers into Grafana.

- `enabled = true` — run that helper.
- `defaultDatasourceEnabled = true` — add **Prometheus** as the **default** datasource.

**Grafana itself** asks Prometheus for numbers when you open a dashboard.

**`additionalDataSources`** — extra connections. We added **Loki**:

- URL: `http://loki.<env>-monitoring.svc.cluster.local:3100`
- `access = proxy` — browser talks to Grafana; Grafana talks to Loki.
- `isDefault = false` — graphs still use Prometheus unless you pick Loki (logs).

**Imported dashboards** (grafana.com):

- **7249** — Kubernetes cluster.
- **6417** — Kubernetes pods (CPU/memory/restarts for ShopSphere pods too).
- Both use datasource **Prometheus**.

**`grafana.ini` `domain` / `root_url`** — Grafana’s public hostname (`https://grafana.<env>.infralabx.space`) so redirects/links are correct. Ingress still publishes that name.

---

## 4. Loki and Promtail — logs

**Loki** = store for **log lines** (like CloudWatch Logs). Chart **`loki-stack`** in the **same** monitoring namespace. **No** public Loki host.

**20Gi gp3**, retention **168h** (~7 days). ClusterIP **3100**.

**Promtail** = **DaemonSet**, one per node. Reads **container logs on that node**, **sends** them to `http://loki:3100/loki/api/v1/push`. Small CPU/memory limits so every node can run one.

**`grafana` / `prometheus` / `fluent-bit` = false on this chart** — do **not** install a **second** Grafana/Prometheus, and do not install Fluent Bit. You already have Grafana/Prometheus from kube-prometheus-stack. Promtail is the log shipper. False does **not** mean “skip logs from Grafana pods.” Promtail still reads logs from pods on the node unless you add filters (we did not).

**Fluent Bit vs Promtail:** same *job* (one helper per node, copy log lines out). Fluent Bit is what you often point at **CloudWatch Logs**. This lab is **Promtail → Loki**. Do not run both without a reason (duplicate logs, extra cost/pods).

**500 on cart, find the error text:** Network tab shows 500. **Log lines** are in **Loki**, searched in **Grafana Explore**. That is **not** Prometheus. Trace IDs (X-Ray style) are **not** wired in ShopSphere yet.

---

## 5. How traffic and observability sit together (ShopSphere)

```text
You → shop.dev → ALB → frontend → api-gateway → cart-service
                                                      ↓
                                              (app still answers 500)
Promtail on the node  →  Loki (log lines)
kubelet / node-exporter / kube-state-metrics  →  Prometheus (pod CPU, Pending, restarts)

You → grafana.<env>.infralabx.space
         ├─ Prometheus  (graphs)
         └─ Loki        (logs)
```

---

## 6. Adding ShopSphere app numbers later (not in Git yet)

Cart already exposes `/metrics` (`http_requests_total` with status code). Prometheus will **not** read it until a **ServiceMonitor** ticket exists. Example:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cart-service
  namespace: shopsphere-dev   # or shopsphere-prod
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: cart-service
  namespaceSelector:
    matchNames:
      - shopsphere-dev
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

`{ }` on Prometheus will accept this ticket. Repeat per service (product, user, …). Prefer this over `additionalScrapeConfigs`.

---

## 7. Why this stack vs CloudWatch (interview)

You **can** run EKS on CloudWatch only. This is a **choice**, not a law.

**Why we chose Prometheus + Grafana + Loki for ShopSphere**

- Kubernetes-native dashboards and kube-state / node-exporter next to the cluster.
- Same Grafana/PromQL story if the app leaves AWS.
- Tickets (ServiceMonitor) can live in Git next to Helm.
- CloudWatch **log ingest** and **custom metrics** can get expensive at high volume; Loki/Prometheus use **your nodes and EBS** instead (a **cost shift**, not free).

**What we still use AWS for later (not this stack):** ALB 5xx, RDS — those numbers are born in AWS. Grafana can add CloudWatch as another datasource. Not done yet.

**Tradeoffs (say these as a senior)**

| | In-cluster Prometheus / Grafana / Loki | CloudWatch Metrics / Logs / dashboards |
|---|---|---|
| Fit | Kubernetes pods, community dashboards | AWS ALB, RDS, ECS, one IAM story |
| Ops | You run pods, PVCs, upgrades, **extra pod slots** (we hit 17 pods/node) | AWS runs the store; less cluster RAM |
| Cost | Disk + node CPU; ingest not billed per log line the CloudWatch way | Ingest + storage + custom metric price can spike |
| Lock-in | PromQL / Grafana are portable | CloudWatch stays on AWS |
| Logs | Loki + Promtail, 7 days in our values | CloudWatch Logs retention/policies you already know |

**Do not claim a dollar saving on this lab.** Say: “Typical reason is ingest cost plus Kubernetes-native views; we still keep CloudWatch for AWS services; we accept extra pods and disks on the nodes.”

**Diplomatic interview shape:** problem (EKS + volume) → what we keep on AWS (ALB/RDS) → what we moved in-cluster (pod metrics + container logs) → tradeoff (we operate Prometheus/Loki).

---

## 8. What this lab has not done

- ServiceMonitors for cart/product/payment `/metrics`
- Trace IDs (X-Ray / Tempo)
- Slack/email from Alertmanager
- Grafana CloudWatch datasource
- Hardening Grafana admin password
- Proving a CloudWatch vs Loki bill

Those are enhancements after both clusters exist and you have used Grafana on a real failure (Pending pods, gateway 404 probe, seed wiping products).
