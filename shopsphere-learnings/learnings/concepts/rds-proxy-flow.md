# ShopSphere — RDS Proxy Flow

File we are studying: `shopsphere-infra/infra/app-infra/rds-proxy.tf`

This note explains **why** we put RDS Proxy in front of prod Aurora, **what** each Terraform resource does, and **how** that helps when many pods talk to the database.

Dev does **not** use this file. Dev still uses CNPG inside the cluster. `local.rds_enabled` is true only when `env` is `prod`.

Helm still has Aurora host placeholders. We have **not** pointed pods at the proxy hostname yet. This file only **creates** the proxy.

---

## 1. Overview — what we are achieving

Without a proxy, every app pod opens connections **straight to Aurora**.

```text
product-service pod ──┐
user-service pod  ────┼──► Aurora (writer + reader)
order-service pod ────┤
payment-service pod ──┘
```

Problems when traffic and pod count grow:

- Aurora has a **limit** on how many connections it can hold. 30 pods × 10 connections each = 300 sessions on one small database.
- If the **writer dies**, Aurora promotes the reader. Every pod’s old connection **breaks**. Users can see errors until the app reconnects.
- More pods does not always mean a healthier database. It can mean **too many doors** into Postgres.

**RDS Proxy** sits in the middle:

```text
App pods
   ↓  many connections (from Kubernetes)
RDS Proxy
   ↓  fewer reused connections
Aurora cluster (one writer + one reader)
```

What we get:

| Goal | How the proxy helps |
|---|---|
| Control connections | Many pod connections are **multiplexed** onto fewer Aurora connections. |
| Scale pods | You can add pods without a 1:1 increase in Aurora sessions. |
| High availability | Pods stay connected to the **proxy**. If the writer fails over, the proxy finds the new writer. Apps do not all drop at once the same way they would if they talked to Aurora directly. |
| Security | Private subnets, TLS, only EKS may reach the proxy, proxy may only reach Aurora, IAM only reads the four app secrets. |

This is a common AWS production pattern: **pods → proxy → Aurora**, not pods → Aurora.

We still have **one Aurora cluster** (cost-aware: one writer + one reader). The proxy does not add a second database. It is a **door and a pool**.

---

## 2. End-to-end request

Example: product-service inserts a product.

1. The pod has `PRODUCT_DB_HOST` (later this will be the **proxy** hostname) and user/password from ESO (`product_user`).
2. The app opens Postgres on port **5432** to the proxy.
3. The proxy security group allows that only if the caller is the **EKS cluster** security group.
4. The proxy reads `prod/product-db-credentials` from Secrets Manager (using its IAM role) and checks the password.
5. The proxy borrows a connection from its **pool** to Aurora.
6. Aurora’s security group allows that because we added a rule: **proxy SG → RDS SG** on 5432.
7. The write goes to the **writer**. Product catalog **reads** can later use the reader address (or a reader-aware setup). User, order, and payment keep reads on the writer on purpose.

If 50 product pods do this at once, Aurora does not necessarily see 50 × pool-size connections. The proxy reuses backend connections.

If the writer dies:

1. Aurora promotes the reader. That machine **stays** writer. The old writer, when healthy, comes back as the **reader**.
2. Pods can keep their connection to the **proxy**.
3. The proxy opens a new backend session to the new writer.
4. In-flight queries can still fail once; the app should retry. Users are less likely to see a total “cannot connect” storm.

---

## 3. Production practices in this file

- **Prod only** — `count = local.rds_enabled ? 1 : 0` on every resource.
- **Private** — same RDS subnets as Aurora (two zones). No public IP.
- **TLS** — `require_tls = true`. Helm prod uses `sslmode: require`.
- **Least privilege IAM** — proxy can only `GetSecretValue` / `DescribeSecret` on the four **app** secrets. Not the admin secret `prod/shopsphere-rds`. Not `*`.
- **Least privilege network** — EKS → proxy:5432, proxy → Aurora:5432. Not 0.0.0.0/0.
- **Auth from Secrets Manager** — same secrets ESO already syncs for the pods. One source of passwords.
- **One proxy, one cluster** — four `auth` blocks (four users), one target (one Aurora).

---

## 4. Resources in `rds-proxy.tf`

There are **seven** resources. Read them in this order.

### 4.1 `aws_security_group.rds_proxy`

Firewall **on the proxy**, not on Aurora.

| Setting | Meaning |
|---|---|
| `count` | Create only on prod. |
| `name` | `prod-shopsphere-rds-proxy` |
| `vpc_id` | Same VPC as the prod EKS cluster. |
| `ingress` port 5432 from EKS cluster SG | Only pods on that cluster may connect to the proxy. |
| `egress` port 5432 to `aws_security_group.rds` | The proxy may only speak Postgres to Aurora. |

Without this group, we cannot attach the proxy to the VPC in a locked-down way.

---

### 4.2 `aws_security_group_rule.rds_from_proxy`

Aurora already has `aws_security_group.rds` (in `rds-network.tf`). That group already allows **EKS → Aurora** (useful for a tunnel or a direct test).

This **extra ingress rule** says: also allow **the proxy’s security group** to Aurora on 5432.

If we skip this rule, pods can reach the proxy, but the proxy cannot reach Aurora. Everything fails.

We add a **rule** instead of rewriting the whole RDS security group so we do not destroy the existing EKS rule.

---

### 4.3 `aws_iam_role.rds_proxy`

The proxy is an AWS service. It is not a Kubernetes pod. It still needs permission to **read passwords** from Secrets Manager.

| Setting | Meaning |
|---|---|
| `name` | `prod-shopsphere-rds-proxy` |
| `Principal.Service = rds.amazonaws.com` | Only the RDS/Proxy service can assume this role. Not a human. Not an EKS pod. |
| `Action = sts:AssumeRole` | That is how AWS hands the role to the proxy. |

This is **not** EKS Pod Identity. Pod Identity is for pods. This role is for the **proxy service**.

---

### 4.4 `aws_iam_role_policy.rds_proxy`

What the proxy is allowed to do after it assumes the role.

| Setting | Meaning |
|---|---|
| `GetSecretValue` | Read the secret JSON (username + password). |
| `DescribeSecret` | See metadata (needed when the proxy refreshes secrets). |
| `Resource` | Only the four ARNs: product, user, order, payment credentials. |

The proxy must know these secrets because a pod connects as `product_user` or `user_user`. The proxy looks up that username in Secrets Manager and checks the password, then opens (or reuses) a backend connection as that user.

Admin `prod/shopsphere-rds` is **not** in this list. You use that secret in the Postgres app. The proxy does not need it for app traffic.

---

### 4.5 `aws_db_proxy.shopsphere`

The proxy itself.

| Setting | Meaning |
|---|---|
| `name` | `prod-shopsphere` |
| `engine_family = POSTGRESQL` | Aurora PostgreSQL. Wrong family = proxy will not work. |
| `role_arn` | The IAM role above. |
| `vpc_subnet_ids` | `data.aws_subnets.rds` — the two private RDS subnets (two availability zones). Same “streets” as Aurora. |
| `vpc_security_group_ids` | The proxy security group. |
| `require_tls = true` | Clients must use TLS. Matches Helm `*_DB_SSLMODE: require`. |
| `auth` (four blocks) | Each block is one Secrets Manager secret the proxy trusts. |
| `auth_scheme = SECRETS` | Login is username/password from those secrets. |
| `iam_auth = DISABLED` | Pods do **not** log in with IAM. They still use ESO env vars (`PRODUCT_DB_USER` / `PRODUCT_DB_PASSWORD`). |

Four `auth` blocks = four app users on **one** proxy. We did not build four proxies.

After apply, AWS gives this proxy a **hostname** (endpoint). That hostname is what Helm should use later instead of `REPLACE_WITH_AURORA_WRITER_HOST`.

---

### 4.6 `aws_db_proxy_default_target_group.shopsphere`

The **pool** settings. This is the “many pods, few Aurora connections” part.

| Setting | Meaning |
|---|---|
| `db_proxy_name` | Attach to our proxy. |
| `max_connections_percent = 90` | Use up to 90% of Aurora’s max connections for this pool. Leave a little room for admin/tunnel. |
| `max_idle_connections_percent = 50` | Keep some idle connections ready so a new request does not always wait to open a new session on Aurora. |
| `connection_borrow_timeout = 120` | If the pool is busy, wait up to 120 seconds for a free connection. Then fail. Better a timeout than hanging forever. |

**High pod count:** 40 pods can each open several connections **to the proxy**. The proxy keeps a smaller set **to Aurora**. That is how we stay inside Aurora’s limit while Kubernetes scales.

---

### 4.7 `aws_db_proxy_target.shopsphere`

Tells the pool **which database** is behind it.

| Setting | Meaning |
|---|---|
| `db_proxy_name` | Our proxy. |
| `target_group_name` | The default target group above. |
| `db_cluster_identifier` | `aws_rds_cluster.shopsphere[0].id` — our one prod Aurora. |

Without this resource, the proxy exists but has **no backend**. Connections would go nowhere.

---

## 5. How this ties to the rest of ShopSphere

| Piece | Role |
|---|---|
| `rds.tf` | One Aurora, two instances (writer + reader). |
| `rds-network.tf` | Subnets, subnet group, Aurora security group. |
| `rds-proxy.tf` | This file — door + pool in front of Aurora. |
| `secrets-manager.tf` + ESO | Username/password in AWS, then Kubernetes Secrets, then pod env. |
| `environments/prod/values.yaml` | Host + `sslmode: require`. Still placeholders; next we put the **proxy** hostname there. |

The seed job still does **not** talk to the proxy. It calls the API. Product-service and user-service (through the proxy, later) write the rows.

---

## 6. High availability and scale — short picture

```text
More users
   → more pods (later HPA)
      → more connections TO the proxy
         → proxy reuses a smaller pool TO Aurora
            → Aurora stays within its connection limit

Writer dies
   → Aurora promotes the reader (that machine stays writer)
   → pods still talk to the proxy hostname
   → proxy reconnects to the new writer
   → old writer, when healthy, comes back as the reader
```

**1 writer + 1 reader** is enough for this design. The proxy is what makes many pods safe. We do not need a second reader just to survive scale.

---

## 7. What we have not done yet

- Point Helm `PRODUCT_DB_HOST` (and the others) at the **proxy endpoint**.
- Store that endpoint next to `host` / `reader_host` in `prod/shopsphere-rds` if we want one place to copy from.
- Run the SQL files that create the four databases and four users. The proxy can authenticate users only after those users exist in Aurora.
- Apply Terraform. This is still code on disk.

---

## 8. Files to open

- `shopsphere-infra/infra/app-infra/rds-proxy.tf` — everything in this note
- `shopsphere-infra/infra/app-infra/rds.tf` — cluster + two instances
- `shopsphere-infra/infra/app-infra/rds-network.tf` — Aurora firewall and subnets
- `shopsphere/environments/prod/values.yaml` — where the proxy hostname will go later
