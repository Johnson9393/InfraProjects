# ShopSphere prod secret rotation

This note is only about **prod Aurora database passwords**. Dev uses CloudNativePG and does not use this rotator.

The example throughout is the **user database**. Product, order, and payment follow the same path with different names.

---

## What this design does

1. Terraform creates the first password and stores it in AWS Secrets Manager.
2. The user-service pod reads that password from a Kubernetes Secret and connects to Aurora database `users`.
3. Every 7 days, AWS calls a ready-made Lambda. That Lambda changes `user_user` in Aurora and writes the new password back into Secrets Manager.
4. External Secrets copies the new password into Kubernetes. Reloader restarts the pod so it picks up the new password.

The pod never talks to the Lambda. The Lambda never talks to the pod. Both talk to Aurora and to Secrets Manager.

---

## Files in this story

| File | What it does |
|---|---|
| `shopsphere-infra/infra/app-infra/random.tf` | Generates the first passwords |
| `shopsphere-infra/infra/app-infra/rds.tf` | Creates the Aurora cluster and the starter database `postgres` |
| `shopsphere-infra/scripts/rds/rds-init-databases.sql` | Creates `products`, `users`, `orders`, `payments` |
| `shopsphere-infra/scripts/rds/rds-init-users.sql` | Creates `user_user` and the other app users (no passwords in this file) |
| `shopsphere-infra/infra/app-infra/rds-network.tf` | Aurora security group. Lets EKS pods connect on port 5432 |
| `shopsphere-infra/infra/app-infra/rds-secrets.tf` | Stores the **admin** secret `prod/shopsphere-rds` |
| `shopsphere-infra/infra/app-infra/secrets-manager.tf` | Creates secret containers. Skips the four prod DB secrets so rotation can own them |
| `shopsphere-infra/infra/app-infra/secrets-rotation.tf` | Stores the four app DB secrets, security groups, Lambda stack, and 7-day rotation |
| `shopsphere-infra/infra/app-infra/eso.tf` | Copies AWS secrets into Kubernetes Secrets every hour |
| `shopsphere/helm/shopsphere/values.yaml` | Tells the user-service pod which Kubernetes Secret key to read |
| `shopsphere/helm/shopsphere/templates/user-service.yaml` | Mounts that Secret as `USER_DB_USER` and `USER_DB_PASSWORD` |

---

## Example names for the user database

| Thing | Name |
|---|---|
| Aurora cluster | `prod-shopsphere` |
| Database | `users` |
| Database user | `user_user` |
| AWS secret | `prod/user-db-credentials` |
| Kubernetes Secret | `user-db-credentials` |
| Pod env vars | `USER_DB_USER`, `USER_DB_PASSWORD`, `USER_DB_HOST`, `USER_DB_NAME` |

Admin is separate:

| Thing | Name |
|---|---|
| Admin user | `shopsphere_admin` |
| AWS secret | `prod/shopsphere-rds` |
| Used by | You (tunnel + DBeaver). Not used by the user-service pod |

---

## Step 1 — Create the first passwords

File: `shopsphere-infra/infra/app-infra/random.tf`

```hcl
resource "random_password" "db" {
  for_each = local.secret_envs
  length  = 24
  special = false
}

resource "random_password" "rds_app" {
  for_each = local.rds_enabled ? local.rds_app_secret_names : toset([])
  length  = 24
  special = false
}
```

`random_password.db` is the Aurora admin password for `shopsphere_admin`.

`random_password.rds_app` creates one password per app secret. For this example the key is `user-db-credentials`. That value is the first password for `user_user`.

These resources only generate strings. They do not put anything in AWS yet.

---

## Step 2 — Create the databases

Aurora is one Postgres system. It is not four separate servers. Writer and reader are two machines on that one system.

File: `shopsphere-infra/infra/app-infra/rds.tf`

```hcl
database_name   = "postgres"
master_username = "shopsphere_admin"
master_password = random_password.db[var.env].result
```

AWS creates the cluster and the starter database `postgres`. The admin password goes **straight into Aurora here**. The same password is also saved in Secrets Manager later. The first admin password does not travel from Secrets Manager into Aurora.

The four app databases are created by hand, once, against `postgres`:

File: `shopsphere-infra/scripts/rds/rds-init-databases.sql`

```sql
CREATE DATABASE products;
CREATE DATABASE users;
CREATE DATABASE orders;
CREATE DATABASE payments;
```

Then the app users are created. This file does **not** set passwords:

File: `shopsphere-infra/scripts/rds/rds-init-users.sql`

```sql
CREATE USER product_user WITH LOGIN;
CREATE USER user_user WITH LOGIN;
CREATE USER order_user WITH LOGIN;
CREATE USER payment_user WITH LOGIN;

ALTER DATABASE users OWNER TO user_user;
```

You set `user_user`'s first password once from the secret `prod/user-db-credentials`. After that, weekly rotation updates it.

---

## Step 3 — Store the user password in Secrets Manager

File: `shopsphere-infra/infra/app-infra/secrets-rotation.tf`

First Terraform builds the JSON in memory:

```hcl
"user-db-credentials" = {
  username            = "user_user"
  password            = random_password.rds_app["user-db-credentials"].result
  engine              = "postgres"
  host                = aws_rds_cluster.shopsphere[0].endpoint
  port                = aws_rds_cluster.shopsphere[0].port
  dbname              = "users"
  dbClusterIdentifier = aws_rds_cluster.shopsphere[0].cluster_identifier
}
```

Then this resource writes that JSON into the secret container `prod/user-db-credentials`:

```hcl
resource "aws_secretsmanager_secret_version" "rds_app" {
  for_each = local.rds_app_secret_payloads

  secret_id     = aws_secretsmanager_secret.shopsphere[each.key].id
  secret_string = jsonencode(each.value)

  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

`for_each` does this four times. For the user example, `each.key` is `user-db-credentials`.

`ignore_changes = [secret_string]` is required for rotation. Terraform writes password `aaa` on the first apply. Seven days later AWS changes it to `bbb`. On the next apply, Terraform still has `aaa` in code. Without this block, Terraform would write `aaa` back and undo rotation. With this block, Terraform leaves the new password in AWS.

The admin secret is stored the same way in `rds-secrets.tf`, secret name `prod/shopsphere-rds`.

`secrets-manager.tf` still writes Redis, RabbitMQ, and JWT secrets for prod. An `if` skips the four database secrets so this rotation file is the only writer for those four.

---

## Step 4 — How the user-service pod connects

The pod does not read Secrets Manager. External Secrets copies the AWS secret into a Kubernetes Secret. The pod reads that Kubernetes Secret.

File: `shopsphere-infra/infra/app-infra/eso.tf`

```hcl
refreshInterval = "1h"

data = [
  for mapping in each.value.mappings : {
    secretKey = mapping.secretKey
    remoteRef = {
      key      = "${each.value.env_key}/${each.value.secret_name}"
      property = mapping.property
    }
  }
]
```

For the user database this means:

- Read AWS secret `prod/user-db-credentials`
- Copy field `username` into Kubernetes Secret key `username`
- Copy field `password` into Kubernetes Secret key `password`
- Kubernetes Secret name: `user-db-credentials`
- Repeat every hour

Helm then points the container env vars at that Secret.

File: `shopsphere/helm/shopsphere/values.yaml`

```yaml
USER_DB_USER:
  secretName: user-db-credentials
  secretKey: username
USER_DB_PASSWORD:
  secretName: user-db-credentials
  secretKey: password
```

File: `shopsphere/helm/shopsphere/templates/user-service.yaml`

```yaml
- name: USER_DB_USER
  valueFrom:
    secretKeyRef:
      name: user-db-credentials
      key: username
- name: USER_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: user-db-credentials
      key: password
```

Host and database name are normal env values, not secrets:

- `USER_DB_HOST` = Aurora writer address
- `USER_DB_NAME` = `users`

When a request needs user data, the pod opens a Postgres connection:

- host = Aurora writer
- port = `5432`
- database = `users`
- username = `user_user`
- password = value from the Kubernetes Secret

Aurora allows that connection because of the **RDS security group** (next section). If the password matches, the query runs.

The pod talks to Aurora on port `5432`. Postgres is the protocol. Aurora is the database. There is no second Postgres server beside Aurora.

---

## Step 5 — Security groups

There are two security groups in this rotation path, plus one extra rule.

### Aurora security group (who may connect to the database)

File: `shopsphere-infra/infra/app-infra/rds-network.tf`

```hcl
resource "aws_security_group" "rds" {
  name        = "${var.env}-shopsphere-rds"
  description = "Postgres from the prod EKS cluster only"

  ingress {
    description     = "Postgres from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }
}
```

This is the firewall **on Aurora**. It lets EKS pods, including user-service, connect on port `5432`. The public internet cannot. The rotation Lambda is not an EKS pod, so this rule is not enough for rotation.

### Rotation security group (what the Lambda may send out)

File: `shopsphere-infra/infra/app-infra/secrets-rotation.tf`

```hcl
resource "aws_security_group" "secrets_rotation" {
  name        = "${var.env}-shopsphere-secrets-rotation"
  description = "Secrets Manager rotator to Aurora"

  egress {
    description     = "Postgres to Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds[0].id]
  }

  egress {
    description = "HTTPS to Secrets Manager via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

This is the firewall **on the Lambda**. It is not used by the pod.

- First egress: Lambda may send Postgres (port `5432`) to Aurora’s security group. That is how it logs in as `user_user` and changes the password.
- Second egress: Lambda may send HTTPS (port `443`) out through the NAT gateway. That is how it writes the new password back into Secrets Manager.

`aws_security_group.rds[0].id` is Aurora’s security group. `[0]` exists because prod creates one of those groups.

### Ingress on Aurora for the Lambda

Egress on the Lambda is only half the door. Aurora must also accept the connection.

```hcl
resource "aws_security_group_rule" "rds_from_rotation" {
  type                     = "ingress"
  description              = "Postgres from Secrets Manager rotator"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds[0].id
  source_security_group_id = aws_security_group.secrets_rotation[0].id
}
```

- `security_group_id` = Aurora (the receiver)
- `source_security_group_id` = the Lambda (the sender)

The Lambda starts the connection. Aurora receives it. Aurora does not open a new connection to the Lambda.

Without this rule, the Lambda can try to change `user_user` and Aurora will block it. Then Secrets Manager would have a new password and Aurora would still have the old one. The pod would fail to log in.

---

## Step 6 — Install the AWS rotation Lambda

We did not write Lambda code. We install AWS’s official single-user Postgres rotator.

File: `shopsphere-infra/infra/app-infra/secrets-rotation.tf`

```hcl
resource "aws_serverlessapplicationrepository_cloudformation_stack" "pg_rotation" {
  count = local.rds_enabled ? 1 : 0

  name             = "${var.env}-shopsphere-pg-rotation"
  application_id   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"
  semantic_version = "1.1.618"
  capabilities     = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    functionName        = "${var.env}-shopsphere-pg-rotation"
    endpoint            = "https://secretsmanager.${var.region}.${data.aws_partition.current.dns_suffix}"
    vpcSubnetIds        = join(",", data.aws_subnets.private[0].ids)
    vpcSecurityGroupIds = aws_security_group.secrets_rotation[0].id
  }
}
```

What each field means:

| Field | Meaning |
|---|---|
| `count` | Prod only. Dev has no Aurora |
| `name` | CloudFormation stack name: `prod-shopsphere-pg-rotation` |
| `application_id` | AWS catalog app. Official Postgres rotator |
| `semantic_version` | Pins that AWS app so it does not change under us |
| `capabilities` | Lets the stack create IAM roles the Lambda needs |
| `functionName` | Lambda name: `prod-shopsphere-pg-rotation` |
| `endpoint` | Secrets Manager URL in our region |
| `vpcSubnetIds` | Private subnets. Lambda uses NAT to reach Secrets Manager. RDS subnets have no NAT, so we do not put it there |
| `vpcSecurityGroupIds` | Attaches the rotation security group above |

This resource creates the function. It does not start the 7-day timer.

A custom Lambda could rotate passwords too. For a normal Aurora Postgres user, the AWS function is the usual enterprise choice.

---

## Step 7 — Turn rotation on

```hcl
resource "aws_secretsmanager_secret_rotation" "rds_app" {
  for_each = local.rds_app_secret_payloads

  secret_id           = aws_secretsmanager_secret.shopsphere[each.key].id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.pg_rotation[0].outputs.RotationLambdaARN
  rotate_immediately  = false

  rotation_rules {
    automatically_after_days = 7
  }

  depends_on = [aws_secretsmanager_secret_version.rds_app]
}
```

`for_each` attaches this to the four app secrets. For the user example, `secret_id` is `prod/user-db-credentials`.

`rotation_lambda_arn` is the function from Step 6.

`rotate_immediately = false` so the first apply does not rotate before `user_user` exists in Aurora.

`automatically_after_days = 7` is the timer. Secrets Manager calls the Lambda every 7 days.

`depends_on` waits until the first secret version exists.

A second resource, `aws_secretsmanager_secret_rotation.rds_admin`, does the same for `shopsphere_admin` and secret `prod/shopsphere-rds`. Same Lambda, same 7 days.

---

## Workflow — first time (user database)

```text
random_password.rds_app["user-db-credentials"]
        |
        v
secrets-rotation.tf writes JSON into AWS secret
prod/user-db-credentials
        |
        +--> you set that password once on Aurora user user_user
        |
        v
ESO copies username/password into Kubernetes Secret
user-db-credentials  (every 1 hour)
        |
        v
Helm mounts USER_DB_USER / USER_DB_PASSWORD
        |
        v
user-service pod connects to Aurora
host = writer, db = users, user = user_user
        |
        v
Aurora security group allows EKS on port 5432
```

---

## Workflow — day 7 rotation (user database)

```text
Secrets Manager timer (7 days)
        |
        v
Calls Lambda prod-shopsphere-pg-rotation
        |
        +--> egress 5432 --> Aurora SG
        |    Lambda logs in and changes user_user password
        |
        +--> egress 443 via NAT --> Secrets Manager
             Lambda writes new password into prod/user-db-credentials
        |
        v
Terraform ignore_changes keeps Terraform from writing the old password back
        |
        v
ESO refresh (1 hour) updates Kubernetes Secret user-db-credentials
        |
        v
Reloader restarts user-service pods
        |
        v
Pod connects again with the new password
```

If the Lambda updates Secrets Manager but cannot reach Aurora, the pod will get the new password and Aurora will still expect the old one. That is why both security group rules exist.

---

## What the pod path and the rotation path each use

| Who | Talks to Aurora using | Allowed by |
|---|---|---|
| user-service pod | EKS cluster security group | `aws_security_group.rds` ingress from EKS |
| Rotation Lambda | `aws_security_group.secrets_rotation` | `rds_from_rotation` ingress on Aurora |

Both use port `5432`. They are two different clients.

---

## What we are not doing yet

- We did not write a custom Lambda. We use the AWS rotator.
- Dev does not rotate this way. Dev is CNPG.
- The user-service still uses the writer host for reads and writes. A later app change can send `SELECT` to the reader host. That is not part of rotation.
- Aurora Global Database (another region for DR) is not in this stack yet.
