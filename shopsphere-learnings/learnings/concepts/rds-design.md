# ShopSphere RDS design — high availability, pooling, and future DR

This note is the database design for **prod**. Dev does not use Aurora. Dev uses CloudNativePG inside the cluster.

The example throughout is the **user database**. Product, order, and payment sit in the same Aurora cluster with different database names.

Two timeframes are in this file:

- **Now:** one region (`us-east-1`), one Aurora cluster, one writer, one reader, RDS Proxy.
- **Later:** Aurora Global Database. A second region holds a replica cluster for disaster recovery.

---

## What we are aiming for

ShopSphere needs the user service to keep working when one machine or one Availability Zone fails. It also needs room to grow when many pods open database connections. A later step is surviving a whole-region failure.

Those are three different problems:

| Problem | What we use | Status |
|---|---|---|
| One writer machine or one AZ dies | Aurora writer + reader in two AZs | Implemented |
| Too many pod connections | RDS Proxy connection pool | Created. Pods not pointed at it yet |
| The whole region dies | Aurora Global Database | Not implemented. Design only |

---

## Files in this story

| File | What it does |
|---|---|
| `shopsphere-infra/infra/core-infra/cluster/vars/prod.tfvars` | Two AZs. Dedicated RDS subnets in `us-east-1a` and `us-east-1b` |
| `shopsphere-infra/modules/vpc/vpc.tf` | Creates those RDS subnets |
| `shopsphere-infra/infra/app-infra/rds-network.tf` | Subnet group and Aurora security group |
| `shopsphere-infra/infra/app-infra/rds.tf` | Aurora cluster, writer instance, reader instance |
| `shopsphere-infra/scripts/rds/rds-init-databases.sql` | Creates `users`, `products`, `orders`, `payments` |
| `shopsphere-infra/scripts/rds/rds-init-users.sql` | Creates `user_user` and the other app users |
| `shopsphere-infra/infra/app-infra/rds-proxy.tf` | RDS Proxy in front of the cluster |
| `shopsphere-infra/infra/app-infra/rds-secrets.tf` | Stores writer host, reader host, and proxy host |
| `shopsphere/environments/prod/values.yaml` | User-service host placeholders. Still the raw Aurora writer for now |

A longer proxy-only walkthrough lives in `learnings/concepts/rds-proxy-flow.md`. Password rotation lives in `infra-reflections/secret-rotation.md`.

---

## Example names

| Thing | Name |
|---|---|
| Region today | `us-east-1` |
| Cluster | `prod-shopsphere` |
| Writer instance | `prod-shopsphere-0` |
| Reader instance | `prod-shopsphere-1` |
| App database | `users` |
| App user | `user_user` |
| Writer address | cluster `endpoint` |
| Reader address | cluster `reader_endpoint` |
| Proxy address | `proxy_host` in `prod/shopsphere-rds` |

Writer and reader are two machines. They are not two separate databases. `users`, `products`, `orders`, and `payments` all live in this one cluster.

---

## Step 1 — Put the database in two Availability Zones

File: `shopsphere-infra/infra/core-infra/cluster/vars/prod.tfvars`

```hcl
rds_subnets = [
  {
    cidr              = "10.1.21.0/24"
    availability_zone = "us-east-1a"
    prefix            = "rds-1"
  },
  {
    cidr              = "10.1.22.0/24"
    availability_zone = "us-east-1b"
    prefix            = "rds-2"
  }
]
```

Aurora cannot sit in the public subnets. It also should not share the EKS node subnets. These two RDS subnets are private, one per zone.

File: `shopsphere-infra/infra/app-infra/rds-network.tf`

```hcl
resource "aws_db_subnet_group" "shopsphere" {
  name       = "${var.env}-shopsphere-db"
  subnet_ids = data.aws_subnets.rds[0].ids
}
```

The subnet group is only a named list. The cluster attaches to it. AWS can then place the writer in one zone and the reader in the other.

The same file creates Aurora’s firewall. Pods on EKS may connect on port `5432`. The public internet may not.

```hcl
resource "aws_security_group" "rds" {
  name = "${var.env}-shopsphere-rds"

  ingress {
    description     = "Postgres from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }
}
```

That is the path the user-service pod uses today.

---

## Step 2 — One cluster, two instances

File: `shopsphere-infra/infra/app-infra/rds.tf`

```hcl
resource "aws_rds_cluster" "shopsphere" {
  cluster_identifier = "${var.env}-shopsphere"
  engine             = "aurora-postgresql"
  engine_version     = "15.10"

  database_name   = "postgres"
  master_username = "shopsphere_admin"

  storage_encrypted       = true
  backup_retention_period = 7
}
```

This is the cluster, not the machines. AWS must create one starter database. That name is `postgres`. The app does not use it. We add `users` later with SQL.

```hcl
resource "aws_rds_cluster_instance" "shopsphere" {
  count = local.rds_enabled ? 2 : 0

  identifier         = "${var.env}-shopsphere-${count.index}"
  cluster_identifier = aws_rds_cluster.shopsphere[0].id
  instance_class     = "db.t3.medium"
  publicly_accessible = false
  promotion_tier      = count.index == 0 ? 1 : 2
}
```

`count = 2` means two machines:

- Index `0` → `prod-shopsphere-0`. Preferred writer (`promotion_tier = 1`).
- Index `1` → `prod-shopsphere-1`. Reader (`promotion_tier = 2`).

Aurora copies every write from the writer to the reader in the same region. You do not run a sync job for that.

You connect with addresses, not by picking a machine in DBeaver:

- Writer address → writer machine. Insert, update, delete must go here.
- Reader address → reader machine. Selects can go here later.

If you connect DBeaver only to the writer, you still see `users`. The reader is a live copy in the other zone.

---

## Step 3 — Four databases inside that one cluster

File: `shopsphere-infra/scripts/rds/rds-init-databases.sql`

```sql
CREATE DATABASE products;
CREATE DATABASE users;
CREATE DATABASE orders;
CREATE DATABASE payments;
```

This is not four Aurora systems. It is four databases on `prod-shopsphere`.

The user service uses database `users` and login `user_user`. A request that fetches a user still goes to this same cluster. Only the database name inside Postgres is `users`.

---

## Step 4 — High availability in the region (what we have now)

This is **zone** failure, not region failure.

```text
us-east-1a                         us-east-1b
-----------                        -----------
writer  prod-shopsphere-0          reader  prod-shopsphere-1
RDS subnet 10.1.21.0/24            RDS subnet 10.1.22.0/24

        both hold the same data for database "users"
```

If `us-east-1a` or the writer machine dies, Aurora promotes the reader in `us-east-1b`. That machine becomes the new writer. The writer address (`endpoint`) moves with the role. The app does not need a new hostname for that failover.

The user-service pod may drop its open connections for a short time. Then it reconnects to the same writer address, which now points at the surviving instance.

What this does **not** cover:

- `us-east-1` itself going down. Both machines are in that region.
- Automatic zero-downtime. There is a short gap while promotion happens.

That is high availability. Disaster recovery is the later Global Database section.

---

## Step 5 — Connection pooling for scale (RDS Proxy)

Without a proxy, every pod opens sessions straight to Aurora.

```text
user-service pods
product-service pods
order-service pods
payment-service pods
        |
        v
   Aurora writer
```

Aurora has a limit on how many connections it can hold. More pods can starve the database even when CPU is fine.

RDS Proxy sits in the middle and reuses a smaller set of real database sessions.

File: `shopsphere-infra/infra/app-infra/rds-proxy.tf`

```hcl
resource "aws_db_proxy" "shopsphere" {
  name          = "${var.env}-shopsphere"
  engine_family = "POSTGRESQL"
  require_tls   = true

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.shopsphere["user-db-credentials"].arn
  }
  # product, order, payment secrets are listed the same way
}

resource "aws_db_proxy_default_target_group" "shopsphere" {
  connection_pool_config {
    max_connections_percent      = 90
    max_idle_connections_percent = 50
    connection_borrow_timeout    = 120
  }
}

resource "aws_db_proxy_target" "shopsphere" {
  db_cluster_identifier = aws_rds_cluster.shopsphere[0].id
}
```

What this gives us:

- Many pod connections become fewer Aurora connections. That is the pool.
- The proxy authenticates with the same Secrets Manager secrets the app uses, including `user-db-credentials`.
- If Aurora fails over from writer to reader, the proxy can hide some of that break. Pods keep talking to the proxy hostname.

The proxy has its own security group. EKS talks to the proxy. The proxy talks to Aurora. An extra ingress rule on Aurora allows that proxy path.

**Honest status:** the proxy exists in Terraform. Helm still has `REPLACE_WITH_AURORA_WRITER_HOST`. The user-service pod still connects to the raw writer, not to `proxy_host`. Switching Helm to the proxy is a later cutover, not done yet.

The admin secret already stores the proxy hostname:

```hcl
host         = aws_rds_cluster.shopsphere[0].endpoint
reader_host  = aws_rds_cluster.shopsphere[0].reader_endpoint
proxy_host   = aws_db_proxy.shopsphere[0].endpoint
```

---

## Step 6 — How the user service talks to this design today

Today:

```text
user-service pod
  USER_DB_HOST        = Aurora writer
  USER_DB_READ_HOST   = also the writer (placeholder)
  USER_DB_NAME        = users
  USER_DB_USER        = user_user   (from Kubernetes Secret)
  USER_DB_PASSWORD    = rotated password
        |
        v
  Aurora security group (EKS on 5432)
        |
        v
  writer instance, database "users"
```

The reader is already in sync. The app is not using it for `SELECT` yet. When we add two connections in the application later:

- insert, update, delete → writer host
- select → reader host

We do not connect DBeaver to the reader for that. The pod opens the second connection itself.

After the proxy cutover, the picture becomes:

```text
user-service pod  -->  RDS Proxy  -->  Aurora writer (and reader if we split)
```

---

## Step 7 — Later: Aurora Global Database for DR

This is **not** in Terraform today. This is the design we will add after the current prod path is stable.

Same-region reader is for an AZ failure. Global Database is for a region failure.

### Target shape

```text
Primary region: us-east-1                    DR region: us-west-2 (example)
--------------------------                   -----------------------------
Cluster prod-shopsphere                      Cluster prod-shopsphere-dr
  writer                                     reader (replica)
  reader
  RDS Proxy                                  RDS Proxy (later, in that VPC)
  EKS / user-service                         EKS (standby or active)

Storage copies across regions asynchronously
```

The DR side is a **second cluster**, not a spare instance hanging on the first cluster. It has its own VPC, subnets, and security groups in that region.

Aurora Global Database keeps streaming data from `us-east-1` to `us-west-2`. That copy is **asynchronous**. There can be a short lag. A few of the newest user writes may not be in DR yet. That lag is the recovery point (RPO).

### What happens in a DR event

1. `us-east-1` is gone or we choose to fail away from it.
2. We promote the `us-west-2` cluster. Its reader becomes a writer.
3. Database `users` is already there. We do not recreate it from scratch.
4. The app must start using the **new** writer address (or the DR proxy hostname). DNS or Helm values have to change.
5. User-service pods in DR open connections as `user_user` to database `users`.

This is usually a short outage, not a silent zero-downtime switch, unless we also build extra routing. That outage window is the recovery time (RTO).

The DR cluster does not “sync after the disaster.” It is already receiving a copy. Promotion is the step. Then the application endpoint must follow.

### What we will need to build later

- A second region VPC and EKS, or a clear plan to rebuild compute there
- Aurora Global Database mapping primary `prod-shopsphere` → secondary cluster
- Secrets and rotation in that region, or a planned way to use the promoted cluster
- DNS or config cutover for `USER_DB_HOST`
- A DR test: promote, connect the user service, write one row, fail back

We will not pretend this is already running. Same-region HA is what we have. Global Database is the next DR layer.

---

## End-to-end picture

**Now (one region):**

```text
Request: GET user
        |
user-service pod in us-east-1
        |
password from Kubernetes Secret (copied from Secrets Manager)
        |
Aurora writer in us-east-1a  (database users)
        |
Aurora copies to reader in us-east-1b
        |
If writer/AZ dies: reader is promoted. Same writer hostname.
```

**Scale path (proxy, after Helm cutover):**

```text
Many user-service pods
        |
RDS Proxy pool
        |
Fewer sessions on Aurora
```

**Later DR (Global Database):**

```text
us-east-1 cluster  --async copy-->  us-west-2 cluster
Region fails
        |
Promote us-west-2
        |
Point user-service at the new writer / proxy
```

---

## What is implemented vs what is later

Implemented:

- One prod Aurora PostgreSQL cluster
- Writer + reader in two AZs
- Four app databases on that cluster
- RDS subnets, subnet group, security group
- RDS Proxy and its pool settings
- Writer, reader, and proxy hostnames stored in `prod/shopsphere-rds`

Later:

- Point Helm at the proxy
- Two app connections (writer for writes, reader for reads)
- Aurora Global Database and a DR region
- DR runbook: promote, cut DNS, verify the user service
