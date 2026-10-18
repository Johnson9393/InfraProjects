# ShopSphere secrets and databases — end-to-end flow

This is a walkthrough of how ShopSphere gets passwords from AWS into pods, and how the app finds Postgres. It is written around the real files in this repo and the Helm chart in `shopsphere`. Walk it as one story. Product DB is the example. User, order, payment, Redis, RabbitMQ, and JWT follow the same path with different names.

Nothing in this flow writes a password into `product-service.yaml`. That file only **names** a Kubernetes Secret. The value lives in AWS, then in a Kubernetes Secret, then in the running container’s environment.

---

## What is already running on the cluster (core-infra)

Two operators are installed under `infra/core-infra/k8-services/`. App-infra does not install them again. It only creates objects those operators already know how to handle.

CNPG operator (`cnpg.tf`) watches for `Cluster` objects (`postgresql.cnpg.io/v1`) and turns them into Postgres pods plus Kubernetes Services.

ESO operator (`eso.tf` in k8-services) watches for `ExternalSecret` objects and turns them into normal Kubernetes Secrets. The controller pod runs in `dev-eso` with service account `eso-controller`. Pod Identity (`eso-iam.tf`) lets that account read Secrets Manager paths like `dev/*`.

Until you create tickets for them (ClusterSecretStore, ExternalSecret, CNPG Cluster), those operators are just sitting there.

---

## Scene 1 — Terraform invents the password and parks it in AWS

File: `infra/app-infra/locals.tf` plus `infra/app-infra/secrets-manager.tf`.

You describe the secret in locals: name `product-db-credentials`, username `product_user`, password from `random_password`.

```hcl
"product-db-credentials" = {
  username = "product_user"
  password = random_password.db[var.env].result
}
```

`secrets-manager.tf` creates an AWS secret named `dev/product-db-credentials` (`env` + key) and stores JSON:

`{ "username": "product_user", "password": "<random>" }`

That is the source of truth. The cluster still has no copy.

---

## Scene 2 — ClusterSecretStore: where to talk

File: `infra/app-infra/eso.tf`.

This is not a password. It tells ESO: when you fetch, call AWS Secrets Manager in this region. Name on the cluster: `dev-aws-secrets-manager`.

```hcl
kind = "ClusterSecretStore"
metadata = { name = "${var.env}-aws-secrets-manager" }
spec.provider.aws = {
  service = "SecretsManager"
  region  = var.region
}
```

The ESO pod uses Pod Identity / IAM. You do not put AWS keys in this object.

`enable_eso_secrets = true` in `vars/dev.tfvars` turns this (and the ExternalSecrets) on. Default in `variables.tf` is false.

---

## Scene 3 — ExternalSecret: what to copy

Same file: `eso.tf`. One ExternalSecret per mapping.

For product it means: read AWS secret `dev/product-db-credentials`, take properties `username` and `password`, create/own a Kubernetes Secret named `product-db-credentials` in namespace `shopsphere-dev`, refresh about every hour.

```hcl
kind = "ExternalSecret"
spec = {
  refreshInterval = "1h"
  secretStoreRef = {
    name = "${var.env}-aws-secrets-manager"
    kind = "ClusterSecretStore"
  }
  target = {
    name           = each.value.secret_name
    creationPolicy = "Owner"
  }
  remoteRef = {
    key      = "${each.value.env_key}/${each.value.secret_name}"
    property = mapping.property
  }
}
```

Apply → ESO sees the ExternalSecret → calls AWS on its timer (and on create) → writes a **normal** Kubernetes Secret `product-db-credentials`. Helm and CNPG only ever see that Secret. They never talk to AWS for this.

ESO does not “watch Secrets Manager all day.” It watches ExternalSecret objects in the cluster, then polls AWS on `refreshInterval`.

---

## Scene 4 — Wait, then CNPG creates Postgres

File: `infra/app-infra/databases.tf`.

Creating the ExternalSecret object is not the same as the Kubernetes Secret existing. ESO needs a moment. That is why there is `time_sleep` (~45s) depending on `kubernetes_manifest.external_secrets`, and why `data.kubernetes_secret_v1.cnpg_credentials` depends on that wait plus the namespace.

Then you apply a CNPG `Cluster` named `product-db`. You do not write a Deployment for Postgres. The operator does.

Bootstrap says: database `products`, owner `product_user`, password from Kubernetes Secret `product-db-credentials`.

```hcl
kind = "Cluster"  # postgresql.cnpg.io/v1
spec.bootstrap.initdb = {
  database = each.value.database
  owner    = each.value.owner
  secret   = { name = each.value.secret_name }
}
```

CNPG reads the same Secret ESO just filled, starts Postgres, sets that login, and creates Kubernetes Services in `shopsphere-dev`. The important one for the app is **`product-db-rw`** (read-write, points at the primary). Same pattern for `user-db`, `order-db`, `payment-db`.

Redis and RabbitMQ in this file are not CNPG. One Redis Deployment + Service named `redis`. One RabbitMQ StatefulSet + Service named `rabbitmq`. They pull `redis-credentials` / `rabbitmq-credentials` the same ESO way.

---

## Scene 5 — Helm only names the Secret; the pod gets the value at runtime

Files: `shopsphere/helm/shopsphere/values.yaml` and `templates/product-service.yaml`.

Non-secret config is plain env, including the hostname CNPG published:

`PRODUCT_DB_HOST: product-db-rw`

Secrets are a map of env var → Secret name + key. Still no password in git.

```yaml
secretEnv:
  PRODUCT_DB_USER:
    secretName: product-db-credentials
    secretKey: username
  PRODUCT_DB_PASSWORD:
    secretName: product-db-credentials
    secretKey: password
```

The template turns that into:

```yaml
- name: PRODUCT_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: product-db-credentials
      key: password
```

Same Secret CNPG used at bootstrap. Same password. That is why login works.

---

## How kubelet actually puts the Secret into the container

This part is Kubernetes, not Helm and not ESO.

You apply a Deployment (Helm). The Deployment controller (kube-controller-manager) keeps the right number of ReplicaSets/Pods. The scheduler picks a node. Then **kubelet on that node** is the process that actually starts the container.

For `secretKeyRef` env vars, kubelet talks to the API server, reads Secret `product-db-credentials` in `shopsphere-dev`, and asks the container runtime (containerd) to start the container with environment variables already set (`PRODUCT_DB_USER`, `PRODUCT_DB_PASSWORD`, plus the plain `env` like `PRODUCT_DB_HOST`). The app process sees normal env vars. It does not call AWS. It does not call ESO.

If the Secret is missing at start, the pod stays pending or the container fails to start until the Secret exists. That is another reason ESO must finish before CNPG and before the app.

If someone later updates the Kubernetes Secret (ESO refresh after an AWS rotation), **running pods keep the old env** until they restart. New pods get the new value. Rotation is not live inside an already-running process unless you add something extra (reload, re-exec, file mount + watch). ShopSphere uses env injection, so restart/rollout after a rotate.

(If you had used a volume mount of the Secret as files, kubelet would also keep those files updated on disk. Env vars from `secretKeyRef` do not hot-reload.)

---

## Who talks to whom when the app connects to Postgres

Once the container is up, the Go app reads `PRODUCT_DB_HOST`, `PRODUCT_DB_PORT`, `PRODUCT_DB_NAME`, `PRODUCT_DB_USER`, `PRODUCT_DB_PASSWORD` and opens a TCP connection to Postgres. No extra “secrets sidecar” in that path.

Pieces involved:

- App container (product-service)
- Kubernetes Service `product-db-rw` (ClusterIP, created by CNPG)
- Endpoint/EndpointSlice for that Service (kube-proxy / dataplane sends traffic to the primary pod)
- Postgres pod CNPG created
- CoreDNS (the cluster DNS), so the hostname becomes an IP

Kubelet already finished its job (env vars) before this connection happens.

---

## How `product-db-rw` DNS works

A Kubernetes Service gets a DNS name inside the cluster.

Short name (same namespace): `product-db-rw`  
FQDN: `product-db-rw.shopsphere-dev.svc.cluster.local`

Your app and Helm values use the short name because the product-service pod also runs in `shopsphere-dev`. CoreDNS (Deployment in `kube-system`, Service often `kube-dns`) answers `*.cluster.local`. The pod’s `/etc/resolv.conf` has `search shopsphere-dev.svc.cluster.local svc.cluster.local cluster.local`, so `product-db-rw` expands to the FQDN.

Lookup result is the Service ClusterIP. Traffic to that IP is load-balanced to the ready Postgres primary pod behind `product-db-rw`. CNPG keeps that Service aimed at the writer. If you used `product-db-r` / `product-db-ro`, that would be reads against replicas. ShopSphere uses `-rw` because the app writes.

API gateway NGINX is the same DNS idea: `product-service.shopsphere-dev.svc.cluster.local` (and `api-gateway`, `frontend`, …). Redis is Service `redis`. RabbitMQ is Service `rabbitmq`. All CoreDNS + ClusterIP.

---

## Same Secret, two consumers

Kubernetes Secret `product-db-credentials`:

1. CNPG bootstrap — create the DB user with that password  
2. product-service pod — log in with that password  

ESO is the only component that talks to AWS for this. CNPG and the app only see the Kubernetes Secret.

---

## One-line picture

AWS Secrets Manager (`dev/product-db-credentials`)  
→ ESO operator (IAM + ClusterSecretStore + ExternalSecret)  
→ Kubernetes Secret `product-db-credentials`  
→ CNPG Cluster CR → Postgres + Service `product-db-rw`  
→ Helm Deployment `secretKeyRef`  
→ kubelet injects env into the container  
→ app connects to `product-db-rw` (CoreDNS → ClusterIP → primary pod)

Hourly, ESO may refresh the Kubernetes Secret from AWS. New pods pick it up. Old pods need a restart.

---

## Files to open if you forget

- `infra/app-infra/locals.tf` — what goes into AWS  
- `infra/app-infra/secrets-manager.tf` — AWS secret objects  
- `infra/core-infra/k8-services/eso.tf` and `eso-iam.tf` — operator + IAM  
- `infra/app-infra/eso.tf` — ClusterSecretStore + ExternalSecrets  
- `infra/app-infra/databases.tf` — CNPG clusters, Redis, RabbitMQ, wait for ESO  
- `infra/core-infra/k8-services/cnpg.tf` — CNPG operator  
- `shopsphere/helm/shopsphere/values.yaml` — `secretEnv` + `PRODUCT_DB_HOST`  
- `shopsphere/helm/shopsphere/templates/product-service.yaml` — `secretKeyRef` at pod spec time  
