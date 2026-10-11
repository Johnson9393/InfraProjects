# ShopSphere — Application to PostgreSQL Connection Flow

## 1. Configuration in `values.yaml`

The product service receives its database connection settings through environment variables.

```yaml
env:
  PRODUCT_DB_HOST: product-db-rw
  PRODUCT_DB_PORT: "5432"
  PRODUCT_DB_NAME: products

secretEnv:
  PRODUCT_DB_USER:
    secretName: product-db-credentials
    secretKey: username
  PRODUCT_DB_PASSWORD:
    secretName: product-db-credentials
    secretKey: password
```

- `PRODUCT_DB_HOST`: Kubernetes Service hostname for PostgreSQL.
- `PRODUCT_DB_PORT`: PostgreSQL port.
- `PRODUCT_DB_NAME`: Database the application connects to.
- `secretEnv`: Injects username and password from a Kubernetes Secret into the application container.

## 2. AWS Secrets Manager → ESO → Kubernetes Secret

AWS Secrets Manager stores the database credentials.

Example AWS secret JSON:

```json
{
  "username": "product_user",
  "password": "<generated-password>"
}
```

ESO (External Secrets Operator) retrieves the configured fields and creates or updates the Kubernetes Secret.

Relevant `eso.tf` configuration pattern:

```hcl
target = {
  name           = "product-db-credentials"
  creationPolicy = "Owner"
}

data = [
  {
    secretKey = "username"
    remoteRef = {
      key      = "dev/product-db-credentials"
      property = "username"
    }
  },
  {
    secretKey = "password"
    remoteRef = {
      key      = "dev/product-db-credentials"
      property = "password"
    }
  }
]
```

- `remoteRef.key`: AWS Secrets Manager secret name.
- `remoteRef.property`: JSON field to retrieve.
- `secretKey`: Key name inside the Kubernetes Secret.
- `target.name`: Name of the Kubernetes Secret ESO manages.

The AWS secret name above is an example; use the actual name configured in your `eso.tf`.

## 3. CNPG creates the PostgreSQL cluster

In `databases.tf`, Terraform submits a CNPG `Cluster` resource to Kubernetes.

Relevant configuration pattern:

```hcl
metadata = {
  name      = "product-db"
  namespace = "shopsphere-dev"
}

spec = {
  instances = 1

  bootstrap = {
    initdb = {
      database = "products"
      owner    = "product_user"

      secret = {
        name = "product-db-credentials"
      }
    }
  }
}
```

- Terraform creates the desired Cluster resource.
- The CNPG operator watches the Cluster resource and reconciles it.
- CNPG creates and manages the PostgreSQL Pod and its supporting resources.
- During initial database creation, CNPG uses the referenced Kubernetes Secret for bootstrap credentials.
- `instances = 1` requests one PostgreSQL instance.

## 4. How the database hostname resolves

CNPG automatically creates Services for the cluster.

For a cluster named `product-db`, the read-write Service is:

```text
product-db-rw
```

The application uses that Service hostname:

```yaml
PRODUCT_DB_HOST: product-db-rw
```

The cluster name and PostgreSQL database name serve different purposes:

- Cluster name: `product-db`
- Generated read-write Service: `product-db-rw`
- PostgreSQL database name: `products`

The application hostname must match the generated Service name.

## 5. Complete connection chain

```text
AWS Secrets Manager
        |
        | ESO retrieves username and password
        v
Kubernetes Secret
product-db-credentials
        |
        +----------------------+
        |                      |
        v                      v
CNPG bootstrap          Product-service Pod
        |                      |
        v                      | Reads DB host, port,
PostgreSQL initialized         | database name and credentials
with database and owner       |
                               v
                       product-db-rw:5432
                               |
                               v
                       Kubernetes Service
                               |
                               v
                       Ready primary PostgreSQL Pod
                               |
                               v
                       Database: products
```

## 6. What happens when the PostgreSQL Pod restarts?

- The Pod can receive a different IP address.
- CNPG manages the database instance and its recovery or recreation.
- Kubernetes updates the Service endpoints as the database instance becomes ready.
- The application continues using `product-db-rw`; it does not need the Pod IP.

The Service DNS name remains stable, although connections can fail temporarily during a restart.

## 7. Practical verification commands

Check the CNPG cluster:

```bash
kubectl get clusters.postgresql.cnpg.io -n shopsphere-dev
```

Check PostgreSQL Pods:

```bash
kubectl get pods -n shopsphere-dev
```

Check CNPG Services:

```bash
kubectl get svc -n shopsphere-dev
```

Check the Kubernetes Secret exists without printing its credentials:

```bash
kubectl get secret product-db-credentials -n shopsphere-dev
```

Check the product-service environment variable names and values:

```bash
kubectl exec -n shopsphere-dev deploy/product-service -- printenv PRODUCT_DB_HOST PRODUCT_DB_PORT PRODUCT_DB_NAME
```

Check the product-service logs:

```bash
kubectl logs -n shopsphere-dev deploy/product-service
```

## 8. Important distinction

- `values.yaml` configures the application's database connection.
- ESO synchronizes credentials from AWS Secrets Manager into Kubernetes Secrets.
- CNPG manages PostgreSQL cluster resources and uses the Secret during initial database bootstrap.
- The Kubernetes Service provides a stable hostname for database connections.
- Updating a Kubernetes Secret does not automatically rotate an existing PostgreSQL user's password. Password rotation requires a separate workflow.