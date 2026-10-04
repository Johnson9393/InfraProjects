# ShopSphere Docker Compose — Practical Concept Examples

This README explains the important Docker Compose concepts used in ShopSphere with simple practical examples.

---

## 1. Service URL

A service URL tells one application **where another application is running**.

Example from ShopSphere:

```yaml
ORDER_SERVICE:
  CART_SERVICE_URL: http://cart-service:8003
```

Meaning:

```text
Order Service
     ↓
http://cart-service:8003
     ↓
Cart Service
```

Here:

* `cart-service` = Docker service name
* `8003` = Cart Service container port

Docker's internal DNS resolves `cart-service` to the correct container.

### Another example

```yaml
PRODUCT_SERVICE_URL: http://product-service:8001
```

The Order Service can call:

```text
http://product-service:8001
```

without knowing the Product Service container IP.

### Important

A service URL represents **application communication**.

It is different from:

```yaml
depends_on:
  cart-service:
    condition: service_started
```

`depends_on` controls startup ordering, while the service URL tells the application **where to send requests**.

---

## 2. Host Port vs Container Port

Example:

```yaml
ports:
  - "8080:80"
```

The format is:

```text
HOST_PORT:CONTAINER_PORT
```

Therefore:

```text
Host machine
localhost:8080
      ↓
API Gateway container:80
```

From your browser:

```text
http://localhost:8080
```

But another Docker container uses:

```text
http://api-gateway:80
```

### Rule

```text
Host → Container
    use published host port

Container → Container
    use service name + container port
```

---

## 3. Bind Mount

A bind mount connects a **specific host directory/file** to a location inside the container.

Example:

```yaml
volumes:
  - ./frontend:/apps
```

This means:

```text
Host
./frontend
    ↓
Container
/apps
```

If you modify:

```text
./frontend/src/App.jsx
```

on your host, the container sees the change under:

```text
/apps/src/App.jsx
```

### Another example

Your API Gateway uses:

```yaml
volumes:
  - ./apps/api-gateway/nginx.conf:/etc/nginx/nginx.conf:ro
```

Meaning:

```text
Host nginx.conf
      ↓
Container /etc/nginx/nginx.conf
```

`ro` means **read-only**.

This is useful when you want to provide configuration files from the host to a container.

---

## 4. Anonymous Volume

Example:

```yaml
volumes:
  - /apps/node_modules
```

There is no host path and no explicit volume name.

Docker creates/manages the storage automatically.

In the frontend:

```text
Host
./frontend
     ↓
Container /apps
     │
     └── /apps/node_modules
             ↓
       Docker-managed volume
```

Why?

The bind mount:

```yaml
./frontend:/apps
```

mounts the whole `/apps` directory.

The separate:

```yaml
/apps/node_modules
```

volume prevents the container's `node_modules` from being replaced by the host's directory contents.

### Simple difference

```text
Bind mount
./frontend:/apps
→ specific host path

Anonymous volume
/apps/node_modules
→ Docker manages the storage
```

---

## 5. Named Volume

A named volume has an explicit name and is normally declared in the top-level `volumes` section.

Example:

```yaml
volumes:
  products-data:
```

Then:

```yaml
volumes:
  - products-data:/var/lib/postgresql/data
```

Meaning:

```text
PostgreSQL
    ↓
/var/lib/postgresql/data
    ↓
products-data volume
```

The database data survives container recreation.

ShopSphere uses named volumes for things such as:

```text
products-data
users-data
orders-data
payments-data
redis-data
rabbitmq-data
```

---

## 6. Bridge Network

ShopSphere defines:

```yaml
networks:
  ecommerce-network:
    driver: bridge
```

A bridge network provides a private network for containers running on the same Docker host.

Conceptually:

```text
ecommerce-network
      │
      ├── api-gateway
      ├── product-service
      ├── user-service
      ├── cart-service
      ├── order-service
      ├── postgres
      ├── redis
      └── rabbitmq
```

Containers can communicate using service names.

Example:

```text
product-service → postgres-products:5432
cart-service    → redis:6379
order-service   → rabbitmq:5672
seed-job        → api-gateway:80
```

Docker's internal DNS resolves the service names.

### Why create our own bridge network?

For multiple related containers, a user-defined bridge network gives us predictable service-to-service communication and DNS-based service discovery.

---

## 7. Database Configuration Correlation

PostgreSQL is configured with:

```yaml
POSTGRES_DB: products
POSTGRES_USER: ecommerce_user
POSTGRES_PASSWORD: secure_password_123
```

Product Service receives:

```yaml
PRODUCT_DB_HOST: postgres-products
PRODUCT_DB_PORT: 5432
PRODUCT_DB_USER: ecommerce_user
PRODUCT_DB_PASSWORD: secure_password_123
PRODUCT_DB_NAME: products
```

The relationship is:

```text
PostgreSQL                    Product Service
──────────                    ───────────────
DB = products        ←→       PRODUCT_DB_NAME
User = ecommerce_user ←→      PRODUCT_DB_USER
Password = ...       ←→       PRODUCT_DB_PASSWORD
Container = postgres-products ← PRODUCT_DB_HOST
Port = 5432          ←→       PRODUCT_DB_PORT
```

The Product Service does not receive these values **from PostgreSQL**.

Both sides are configured consistently so the application can connect to the database.

---

## 8. Environment Variables

Compose can provide configuration to the application:

```yaml
environment:
  PRODUCT_DB_HOST: postgres-products
  PRODUCT_DB_PORT: 5432
  PRODUCT_DB_NAME: products
```

The application reads them from its runtime environment.

For example, Go code can use:

```text
os.Getenv("PRODUCT_DB_HOST")
os.Getenv("PRODUCT_DB_PORT")
```

### Troubleshooting

If a service cannot connect to its database:

```text
Docker Compose
     ↓
Check environment variable
     ↓
Find the variable in source/config
     ↓
Check exact variable name
     ↓
Check value
     ↓
Check application logs
```

For example:

```text
PRODUCT_DB_HOST
```

must match what the application actually reads.

---

## 9. JWT Secret

Example:

```yaml
JWT_SECRET: your-super-secret-jwt-key
```

The application uses this secret for JWT signing/verification.

Simplified flow:

```text
User Login
    ↓
Authentication
    ↓
JWT generated
    ↓
Client sends JWT
    ↓
Service verifies JWT using secret
```

If multiple services need to validate the same JWT, they need compatible JWT configuration/secrets.

### Production

Do not keep real JWT secrets directly in `docker-compose.yml`.

Use a proper secret-management solution such as:

```text
AWS Secrets Manager
Kubernetes Secrets
EKS Pod Identity / IAM
```

depending on the deployment architecture.

---

## 10. Redis Configuration

ShopSphere Cart Service uses:

```yaml
REDIS_HOST: redis
REDIS_PORT: 6379
REDIS_PASSWORD: redis_password_123
REDIS_DB: 0
```

So the connection is:

```text
Cart Service
     ↓
redis:6379
     ↓
Redis
```

`REDIS_DB=0` means the application connects to Redis logical database 0.

The application reads these values and creates its Redis client using them.

---

## 11. RabbitMQ Configuration

RabbitMQ exposes two important ports:

```text
5672
→ Application AMQP communication

15672
→ RabbitMQ Management UI
```

Example:

```text
Order Service
     ↓
RabbitMQ :5672
     ↓
Notification Service
```

The Management UI can be accessed from the host using the published port:

```text
localhost:15672
```

The services themselves communicate internally using:

```text
rabbitmq:5672
```

---

## 12. `depends_on`

`depends_on` controls **startup ordering**.

Example:

```yaml
product-service:
  depends_on:
    postgres-products:
      condition: service_healthy
```

Meaning:

```text
Start PostgreSQL
      ↓
PostgreSQL becomes healthy
      ↓
Start Product Service
```

Another example:

```yaml
frontend:
  depends_on:
    seed-job:
      condition: service_completed_successfully
```

Meaning:

```text
Start seed-job
      ↓
Seed data
      ↓
Exit with code 0
      ↓
Start frontend
```

`depends_on` is about **startup**, not application business dependency.

---

## 13. Healthcheck

Example:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ecommerce_user"]
  interval: 10s
  timeout: 5s
  retries: 5
```

`pg_isready` checks whether PostgreSQL is ready to accept connections.

### Meaning

```text
interval: 10s
→ run the check every 10 seconds

timeout: 5s
→ allow up to 5 seconds for one check

retries: 5
→ repeated failures are considered when determining health
```

The important relationship is:

```text
healthcheck
     ↓
defines what "healthy" means

depends_on: service_healthy
     ↓
waits for that health status
```

---

## 14. Seed Job

The ShopSphere seed job initializes application data.

Its flow is:

```text
Seed Job
    ↓
API Gateway
    ↓
Product/User/Cart APIs
    ↓
Application services
    ↓
Databases / Redis
```

It uses:

```yaml
API_URL: http://api-gateway:80
```

because it is another container on the same Docker network.

The preflight settings:

```text
PREFLIGHT_ATTEMPTS=60
PREFLIGHT_SLEEP=5
```

allow the seed job to retry while required application endpoints become ready.

---

## 15. Practical Mental Model

For ShopSphere, remember these relationships:

```text
PORT MAPPING
Host:8080 → Container:80

SERVICE URL
container → http://service-name:container-port

BIND MOUNT
host path → container path

ANONYMOUS VOLUME
Docker-managed storage → container path

NAMED VOLUME
named persistent storage → container path

BRIDGE NETWORK
multiple containers → private Docker network

HEALTHCHECK
defines whether a service is healthy

DEPENDS_ON
controls startup ordering

JWT_SECRET
used by application for JWT signing/verification

ENVIRONMENT VARIABLES
runtime configuration passed from Compose → application
```

These concepts together explain most of the important networking, configuration, storage, and startup behavior in the ShopSphere Docker Compose setup.
