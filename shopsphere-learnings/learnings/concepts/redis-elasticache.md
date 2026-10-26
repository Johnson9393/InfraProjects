# ShopSphere Redis — ElastiCache for prod

This note is the Redis design for **prod**. Dev does not use ElastiCache. Dev keeps the Redis pod inside the cluster.

The example throughout is the **cart service**. Cart add, read, and delete all go through Redis.

---

## What we are aiming for

ShopSphere stores the shopping cart in Redis. If Redis is one Kubernetes pod, that pod is a single point of failure. If the pod dies, the node dies, or that Availability Zone dies, the cart service cannot add, read, or delete cart items.

ElastiCache is AWS’s managed Redis. We replace the in-cluster Redis pod in prod with a primary and a replica in two AZs. AWS copies cart data to the replica. If the primary dies, AWS promotes the replica. The cart pod keeps using the same hostname.

This is the same split we already use for Postgres:

| Environment | Redis | Postgres |
|---|---|---|
| Dev | In-cluster Redis pod | CloudNativePG |
| Prod | ElastiCache Redis | Aurora |

---

## Files in this story

| File | What it does |
|---|---|
| `shopsphere-infra/infra/app-infra/elasticache-redis.tf` | Security group, subnet group, Redis primary + replica |
| `shopsphere-infra/infra/app-infra/locals.tf` | Prod/dev switch. Adds host into `redis-credentials` on prod |
| `shopsphere-infra/infra/app-infra/databases.tf` | In-cluster Redis pod. Skipped on prod |
| `shopsphere-infra/infra/app-infra/variables.tf` | Node type and Redis version |
| `shopsphere-infra/infra/app-infra/vars/prod.tfvars` | `redis_enabled = false` |
| `shopsphere-infra/infra/app-infra/outputs.tf` | Prints primary and reader hostnames after apply |
| `shopsphere-infra/infra/app-infra/secrets-rotation.tf` | Private subnet lookup. ElastiCache reuses it |
| `shopsphere/helm/shopsphere/values.yaml` | Default `REDIS_HOST: redis` and `REDIS_TLS: "false"` for dev |
| `shopsphere/environments/prod/values.yaml` | Prod `REDIS_HOST` placeholder and `REDIS_TLS: "true"` |
| `shopsphere/app/services/cart-service/src/config/redis.js` | Turns TLS on when `REDIS_TLS=true` |

---

## Example names

| Thing | Name |
|---|---|
| Region | `us-east-1` |
| Replication group | `prod-shopsphere-redis` |
| Primary | Redis node in one AZ |
| Replica | Redis node in the other AZ |
| Port | `6379` |
| AWS secret | `prod/redis-credentials` |
| Kubernetes Secret | `redis-credentials` |
| Cart env | `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_TLS` |

Primary and replica are two Redis machines. They are not two separate Redis products. Cart data lives once, copied to both.

---

## Why not keep the in-cluster Redis pod in prod

File: `shopsphere-infra/infra/app-infra/databases.tf`

The old Redis was one Deployment, `replicas = 1`, and a ClusterIP Service named `redis`. Helm pointed `REDIS_HOST` at that Service name.

That is fine for dev. It is cheap and it sits on nodes we already pay for. It is not fine for prod:

- One pod. One disk. One zone.
- If that pod restarts, carts can vanish unless persistence is perfect.
- We would have to build failover ourselves.

ElastiCache is the managed version. AWS runs the machines, the replica, and the failover.

---

## Step 1 — Prod switch in locals

File: `shopsphere-infra/infra/app-infra/locals.tf`

```hcl
elasticache_enabled     = var.env == "prod"
redis_incluster_enabled = var.redis_enabled && !local.elasticache_enabled
```

`elasticache_enabled` turns the ElastiCache resources on for prod only.

`redis_incluster_enabled` is false on prod, so the Redis Deployment in `databases.tf` is not created. Dev still has `elasticache_enabled = false`, so the in-cluster pod stays.

`prod.tfvars` also sets `redis_enabled = false` so the intent is obvious.

---

## Step 2 — Firewall

File: `shopsphere-infra/infra/app-infra/elasticache-redis.tf`

```hcl
resource "aws_security_group" "elasticache_redis" {
  count = local.elasticache_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-redis"
  description = "Redis from the prod EKS cluster only"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id

  ingress {
    description     = "Redis from EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }
}
```

This is the firewall in front of Redis. Same idea as the Aurora security group.

`count` is 1 on prod, 0 on dev.

`vpc_id` is the prod VPC, taken from the EKS cluster.

The ingress rule allows port `6379` only from the EKS cluster security group. The cart pod can connect. The public internet cannot. The rule is cluster-wide, like Aurora. Only the cart service is written to use Redis.

---

## Step 3 — Subnet group

This is not Redis. It is the named list of private subnets AWS may use when it places the Redis nodes. Same idea as the Aurora DB subnet group.

```hcl
resource "aws_elasticache_subnet_group" "redis" {
  count = local.elasticache_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-redis"
  description = "Private subnets for prod ShopSphere Redis"
  subnet_ids  = data.aws_subnets.private[0].ids
}
```

Aurora uses dedicated RDS subnets (`rds-1`, `rds-2`). ElastiCache uses the existing EKS private subnets. Both are private. Both are inside the VPC.

Those private subnets already span `us-east-1a` and `us-east-1b`. That is required for multi-AZ. One Redis node can sit in each zone.

The cart pod is also in those private subnets. It reaches Redis inside the VPC. Redis has no public address.

`data.aws_subnets.private` lives in `secrets-rotation.tf`. ElastiCache reuses that lookup.

---

## Step 4 — Replication group (the actual Redis)

This resource creates the primary and the replica.

```hcl
resource "aws_elasticache_replication_group" "redis" {
  count = local.elasticache_enabled ? 1 : 0

  replication_group_id = "${var.env}-shopsphere-redis"
  description          = "Prod ShopSphere Redis for cart"
  engine               = "redis"
  engine_version       = var.elasticache_engine_version
  node_type            = var.elasticache_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.redis[0].name
  security_group_ids = [aws_security_group.elasticache_redis[0].id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis[var.env].result

  snapshot_retention_limit = 1
  snapshot_window          = "07:00-08:00"
  maintenance_window       = "sun:08:00-sun:09:00"
}
```

### Identity and engine

| Parameter | What it is | Why we set it |
|---|---|---|
| `count` | Create only on prod | Dev keeps the in-cluster pod |
| `replication_group_id` | AWS name: `prod-shopsphere-redis` | Stable name for the Redis system |
| `description` | Human label | Cart Redis, not a generic cache |
| `engine` | `redis` | Cart already speaks Redis |
| `engine_version` | `7.1` from `var.elasticache_engine_version` | Matches Redis 7 |
| `node_type` | `cache.t3.micro` | Small lab size. Raise this if cart traffic grows |
| `port` | `6379` | Same port the cart service already uses |
| `parameter_group_name` | `default.redis7` | AWS default Redis 7 settings |

### High availability

| Parameter | What it is | What it solves |
|---|---|---|
| `num_cache_clusters = 2` | One primary + one replica | Two machines, not one |
| `automatic_failover_enabled = true` | AWS promotes the replica if the primary dies | Cart does not wait for us to fail over by hand |
| `multi_az_enabled = true` | The two machines sit in two AZs | `us-east-1a` dying does not take Redis down |
| `subnet_group_name` | Private subnets from Step 3 | Where those two machines are placed |
| `security_group_ids` | Firewall from Step 2 | Only EKS may connect |

AWS copies cart data from the primary to the replica. We do not run a sync job.

The cart service uses the **primary endpoint** today. The replica is for failover. There is also a **reader endpoint**, like Aurora’s reader host, if we later send cart reads there. We have not split reads yet.

### Encryption and password

| Parameter | What it is | What it solves |
|---|---|---|
| `at_rest_encryption_enabled` | Encrypt cart data on disk | A copied volume is not readable cart JSON |
| `transit_encryption_enabled` | Encrypt cart traffic on the network | Add/read/delete cart is TLS on the wire |
| `auth_token` | Redis password | Same value as `prod/redis-credentials` |

**At rest** = data sitting on the Redis disk. **Transit** = data travelling between the cart pod and Redis.

Transit encryption is why prod sets `REDIS_TLS=true`. The cart client must use TLS. Dev keeps `REDIS_TLS=false` because the in-cluster pod does not require it.

`auth_token` is not a second password. `random_password.redis` is generated once. Terraform writes that value into Secrets Manager and into ElastiCache. They must match, or the cart pod cannot log in.

Secrets Manager is for the pod (ESO → Kubernetes Secret → `REDIS_PASSWORD`). Terraform already has the password, so it does not read it back from Secrets Manager to create ElastiCache.

### Backup and patching

| Parameter | What it is | What it solves |
|---|---|---|
| `snapshot_retention_limit = 1` | Keep one day of Redis snapshot | A short restore point |
| `snapshot_window` | `07:00-08:00` UTC | When AWS takes that snapshot |
| `maintenance_window` | Sunday `08:00-09:00` UTC | When AWS may patch Redis |

Snapshot window is backup. Maintenance window is planned patching. They sit next to each other on Sunday morning so this does not hit peak cart traffic. With two nodes, AWS can patch one while the other stays primary. Cart can still see a short blip.

---

## Step 5 — Password and host in Secrets Manager

The password is always stored:

```hcl
"redis-credentials" = merge(
  {
    password = random_password.redis[var.env].result
  },
  local.elasticache_enabled ? {
    host        = aws_elasticache_replication_group.redis[0].primary_endpoint_address
    reader_host = aws_elasticache_replication_group.redis[0].reader_endpoint_address
    port        = aws_elasticache_replication_group.redis[0].port
    engine      = "redis"
  } : {}
)
```

Dev secret JSON is only `password`. Prod secret JSON also has `host`, `reader_host`, `port`, and `engine`.

ESO still copies only `password` into the Kubernetes Secret `redis-credentials`. Helm still reads `REDIS_PASSWORD` from that Secret. Helm reads `REDIS_HOST` from values, not from ESO.

---

## Step 6 — How the cart pod finds Redis

Discovery is the hostname, not a node IP.

After `terraform apply` on prod app-infra, output `elasticache_redis_primary_endpoint` is the stable primary DNS name. Paste it into `shopsphere/environments/prod/values.yaml`:

```yaml
cartService:
  env:
    REDIS_HOST: REPLACE_WITH_ELASTICACHE_PRIMARY_HOST
    REDIS_PORT: "6379"
    REDIS_TLS: "true"
```

The cart pod then connects with:

- host = ElastiCache primary endpoint
- port = `6379`
- password = Kubernetes Secret `redis-credentials` / `password`
- TLS = on

If the primary node dies, AWS points that **same hostname** at the promoted replica. You do not update Helm on every failover. Same idea as the Aurora writer endpoint.

The cart image must be rebuilt once so `redis.js` honours `REDIS_TLS`:

```js
const redisTlsEnabled = process.env.REDIS_TLS === 'true' || process.env.REDIS_TLS === '1';

socket: {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  tls: redisTlsEnabled,
}
```

---

## Workflow

**Dev**

```text
cart pod
  REDIS_HOST = redis          (Kubernetes Service)
  REDIS_TLS  = false
        |
        v
in-cluster Redis pod
```

**Prod, after you paste the hostname**

```text
Request: add item to cart
        |
cart-service pod
  REDIS_HOST = elasticache primary DNS
  REDIS_TLS  = true
  REDIS_PASSWORD from Kubernetes Secret
        |
        v
ElastiCache security group (EKS on 6379)
        |
        v
primary Redis  (us-east-1a or us-east-1b)
        |
AWS copies cart data to replica in the other AZ
        |
If primary/AZ dies: replica is promoted.
Same REDIS_HOST still works.
```

---

## What this does not cover yet

- Cart reads still go to the primary. The reader endpoint exists; the app does not use it yet.
- This is one region. A whole `us-east-1` outage still takes Redis down. Global datastore would be a later DR layer.
- RabbitMQ is still one in-cluster StatefulSet. That is the next high-availability piece.
- Helm still has the placeholder until you paste the endpoint after apply.
