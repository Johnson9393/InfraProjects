# ShopSphere lab — issues we fixed, and how the pieces connect

This is a recap from the review before we started applying anything for real. File paths are from the Infra repo (`shopsphere`, `shopsphere-infra`, `.github/workflows`).

---

## How the chain actually works (short)

**Helm** is the ShopSphere recipe: Deployments, Services, env vars. Chart defaults live in `shopsphere/helm/shopsphere/values.yaml`. Dev overrides live in `shopsphere/environments/dev/values.yaml`. Templates under `shopsphere/helm/shopsphere/templates/` pull those values. GitHub Actions does **not** helm-install the app.

**ESO** is the copier. Operators are installed in core (`shopsphere-infra/infra/core-infra/k8-services/eso.tf`). App-infra (`eso.tf`) only creates tickets: ClusterSecretStore = “talk to Secrets Manager in this region”; ExternalSecret = “copy this AWS secret into this Kubernetes Secret.” The ESO pod uses Pod Identity (IAM), not keys in YAML. Helm never contains passwords; pods use `secretKeyRef`.

**CNPG** is Postgres-in-the-cluster. Operator in `k8-services/cnpg.tf`. App-infra `databases.tf` creates `Cluster` objects. CNPG reads the same K8s Secrets ESO filled, creates DBs, and publishes DNS like `product-db-rw`. Helm points `PRODUCT_DB_HOST` at that name. Redis/RabbitMQ in the same file are **not** CNPG — one Redis Deployment, one RabbitMQ StatefulSet — but they use ESO secrets the same way.

**Argo CD** is the installer. Terraform puts it in `dev-argocd`, with Ingress on the shared ALB. It does nothing for ShopSphere until an Application exists. That ticket is `shopsphere/gitops/shopsphere-dev.yaml`: clone this GitHub repo, this Helm path, these value files, put it in `shopsphere-dev`. Git is desired state. Argo makes the cluster match. Image tags in values must exist in ECR or pods ImagePullBackOff.

**GitHub Actions** builds images (ECR + SHA) and runs Terraform for the three stacks. It does not deploy Helm. OIDC bootstrap is **manual once** (`shopsphere-infra/bootstrap/github-oidc`) so Actions can assume IAM roles. Destroy is in the same infra workflow, reverse order, and does **not** delete OIDC or the S3 state bucket.

Flow in one line: AWS Secrets Manager → ESO → K8s Secret → CNPG (create DB) + Helm pods (login) ; Git Helm+values → Argo → those pods ; GitHub → ECR images + Terraform infra.

---

## Issues we found and how we fixed them

### Helm / ShopSphere app

**Service names vs Ingress / NGINX**  
Issue: Helm named Services `shopsphere-frontend`, `shopsphere-api-gateway`, etc. Terraform Ingress and NGINX looked for `frontend`, `api-gateway`, `product-service`. ALB and the gateway would miss backends.  
Fix: Service `metadata.name` in the templates is the short name (`frontend`, `api-gateway`, `product-service`, …). Deployments can keep the long name. Files: `shopsphere/helm/shopsphere/templates/*.yaml` (including `user-service.yaml`, which we almost missed).

**Seed job still called the old gateway name**  
Issue: `seed-job.yaml` waited on `shopsphere-api-gateway`. That Service was gone.  
Fix: wait URL and `API_URL` use `api-gateway.<namespace>.svc.cluster.local`. File: `shopsphere/helm/shopsphere/templates/seed-job.yaml`.

**Product-service probes**  
Issue: `initialDelaySeconds` / `periodSeconds` sat **inside** `httpGet` (invalid). Other services were already correct.  
Fix: those fields sit next to `httpGet`, not inside it. File: `shopsphere/helm/shopsphere/templates/product-service.yaml`.

**Dev ECR URLs**  
Issue: `environments/dev/values.yaml` had `<DEV_ECR_ACCOUNT_ID>`. Chart `values.yaml` dummy names like `shopsphere/product-service` are fine as defaults.  
Fix: real registry in the **dev** overlay. Seed repo name is `dev-shopsphere-seed` (not `seed-job`), matching Terraform ECR. Tags stayed `1.0.0` on purpose — first lab we paste the build SHA by hand. File: `shopsphere/environments/dev/values.yaml`.

**Helm ingress values**  
Issue: ingress keys in values, no Ingress template. Dead config.  
Fix: leave it. Real Ingress is Terraform `app-infra/ingress.tf`.

---

### shopsphere-infra / `databases.tf`

**Redis and RabbitMQ looping over Postgres clusters**  
Issue: `for_each = local.cnpg_clusters_effective` created four Redis (all named `redis`) and four RabbitMQs. CNPG list is only product/user/order/payment DBs.  
Fix: `count = 1`, namespace `local.cluster_namespace`. One Redis, one RabbitMQ.

**Left `each.value` after switching to `count`**  
Issue: with `count` there is no `each`. Terraform would fail.  
Fix: `local.cluster_namespace`, `var.env`, secrets `[0]`. Last leftover: RabbitMQ Service `environment = each.key` → `var.env`.

**CNPG secret data source depended on itself**  
Issue: `depends_on = [data.kubernetes_secret_v1.cnpg_credentials]` does nothing. Apply could race ESO.  
Fix: wait on ExternalSecrets + `time_sleep` (~45s), then read the Secret. Redis/RabbitMQ data sources use the same wait. File: `shopsphere-infra/infra/app-infra/databases.tf`.

---

### Other Terraform

**Namespace created for every env on a dev apply**  
Issue: `namespace.tf` `for_each = var.environments` made `shopsphere-prod` too.  
Fix: one namespace `local.cluster_namespace`. File: `shopsphere-infra/infra/app-infra/namespace.tf`.

**ESO Helm chart not pinned**  
Issue: no `version` on `helm_release.eso`. Chart/CRDs could jump; app-infra already uses `external-secrets.io/v1`.  
Fix: `version = var.eso_chart_version` (default `2.13.0`). Files: `k8-services/eso.tf`, `k8-services/variables.tf`.

**Gitignore hid env tfvars**  
Issue: `*.tfvars` ignored `vars/dev.tfvars`. Fine on your laptop; clone/CI missing the file.  
Fix: `!**/vars/*.tfvars`. Secrets still not in that folder. File: `shopsphere-infra/.gitignore`.

**App-infra needs Razorpay + notification AWS keys**  
Issue: those variables have no default. Apply would stop.  
Fix: **repo secrets** + `TF_VAR_*` on the workflow. Not Environment `dev` secrets (plan has no `environment:`). Placeholders OK until real Razorpay. Files: `.github/workflows/shopsphere-infra.yaml`, GitHub repo secrets.

**Left for later (not bugs we “fixed”)**  
`t3.small` — you’ll see Pending, then size up. EKS API `0.0.0.0/0` — later jump host / your IP. Notification AWS keys in the pod — later Pod Identity like ESO. Real Razorpay. Prod cluster + same-image promote. Redis has no disk (Deployment).

---

### GitHub Actions

**OIDC is not in the infra workflow**  
Issue: Actions cannot assume a role that does not exist yet.  
Fix: apply `shopsphere-infra/bootstrap/github-oidc` **from the laptop** once. `TF_VAR_github_owner` / `TF_VAR_github_repository` there tell **AWS** which GitHub repo to trust. They are not the same as `shopsphere-infra.yaml` secrets. Keep this stack + S3 on destroy.

**Terraform role ARN**  
Issue: workflow uses `vars.AWS_TERRAFORM_ROLE_ARN_DEV`, not a hardcoded ARN.  
Fix: GitHub **Actions variable** (not a secret) = `github-terraform-role` ARN.

**ECR role was hardcoded, then broken mustache**  
Issue: `shopsphere-build.yaml` had the account in git, then `{{ vars.AWS_ECR_ROLE_ARN }}` (Helm style). Actions needs `${{ }}`.  
Fix: repo variable `AWS_ECR_ROLE_ARN`; `AWS_ROLE_ARN: ${{ vars.AWS_ECR_ROLE_ARN }}`. File: `.github/workflows/shopsphere-build.yaml`.

**`--cache-to` quotes**  
Issue: quote closed too early; buildx could fail.  
Fix: `mode=max` and friends inside the same quotes.

**Build job sat on Environment `dev`**  
Issue: if `dev` has apply approvals, **image builds wait too**.  
Fix: remove `environment:` from the build job. Builds auto; apply/destroy still use Environment `dev`. `fail-fast: false` on the matrix = one service fail, others still finish.

**Terraform wrapper**  
Issue: `setup-terraform` wraps the binary; plan-file apply across jobs often breaks.  
Fix: `terraform_wrapper: false` on **plan and apply** (and destroy). File: `shopsphere-infra.yaml`.

**Destroy**  
Issue: no destroy path; you’d leave EKS running.  
Fix: same workflow, `action: apply | destroy`. Destroy (after approval) deletes Argo Application, then app-infra → k8-services → cluster. Not OIDC, not the state bucket. `infra_path` is ignored on destroy.

---

### Argo

**Operator without a ticket**  
Issue: Argo installed, no Application → no ShopSphere pods.  
Fix: `shopsphere/gitops/shopsphere-dev.yaml` (repo, Helm path, dev values, dest `shopsphere-dev`). Apply that **after** k8-services + app-infra. Private GitHub needs a repo credential in Argo. Image tags in values must match a real ECR SHA (manual this lab).

---

## Lab apply order (when we do it)

1. Bootstrap OIDC (laptop), if not already.  
2. GitHub: variables + secrets.  
3. Workflow apply: cluster → k8-services → app-infra.  
4. Build images, paste SHA into `environments/dev/values.yaml`.  
5. Argo repo login, apply Application.  
6. When the lab is done: workflow **destroy** (not OIDC, not S3).

Argo admin password: Secret `argocd-initial-admin-secret` in `dev-argocd`. RabbitMQ: `rabbitmq_user` + Secret `rabbitmq-credentials` in `shopsphere-dev`; UI via port-forward `15672`.
