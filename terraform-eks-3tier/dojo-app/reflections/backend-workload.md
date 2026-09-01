# Backend Kubernetes Deployment — Learning Notes

## 1. Purpose

The backend is deployed as an internal Kubernetes workload. It is responsible for serving APIs and communicating with the PostgreSQL RDS database.

Current architecture:

Frontend → Backend Service → Backend Pods → RDS

The backend does not need direct public access, so its Kubernetes Service uses `ClusterIP`.

---

## 2. Backend Deployment

The backend Deployment defines:

- Application image
- Number of replicas
- Pod labels
- Container port
- Resource requests/limits
- Readiness probe
- Liveness probe
- Runtime environment variables

Current backend configuration:

- Replicas: `2`
- Application port: `8000`
- Service port: `8080`
- Container/target port: `8000`

The Dockerfile confirms the application listens on port `8000`:

`EXPOSE 8000`

and:

`gunicorn --bind 0.0.0.0:8000 run:app`

Therefore the Kubernetes Deployment uses:

`containerPort: 8000`

and the probes also check port `8000`.

---

## 3. Labels and Selectors

Deployment:

`spec.selector.matchLabels.app = backend`

Pod template:

`spec.template.metadata.labels.app = backend`

These two must match because the Deployment uses the selector to identify the Pods it manages.

The Backend Service also has:

`selector = { app = "backend" }`

This is what connects the Service to the backend Pods.

Flow:

Deployment selector → Backend Pod label → Backend Service selector → Backend Pods

The Deployment's own top-level `metadata.labels` is mainly metadata for the Deployment itself; it is not what the Service uses for Pod discovery.

---

## 4. Container Port

The backend application listens on:

`8000`

Therefore:

`containerPort: 8000`

This field documents the port the containerized application expects to receive traffic on. It does not itself expose the application outside the Pod.

The Service handles access to the Pods.

---

## 5. Service Port vs Target Port

Backend Service:

- `port = 8080`
- `targetPort = 8000`
- `type = ClusterIP`

Traffic flow:

Frontend → `backend-service:8080`
→ Service forwards to Pod `:8000`
→ Backend application

`port` is the port exposed by the Kubernetes Service.

`targetPort` is the port where the application is listening inside the Pod.

---

## 6. Why ClusterIP?

The backend is an internal service. Users do not need to directly access it.

`ClusterIP` provides a stable internal Service endpoint while Kubernetes handles routing traffic to the backend Pods.

Example:

`backend-service`
→ ClusterIP `10.100.x.x`
→ Backend Pod 1 / Backend Pod 2

The ClusterIP is a virtual Kubernetes Service IP. It is not the IP of a particular Pod or physical machine, and it is normally reachable only from inside the cluster/network.

Pod IPs can change, but the Service provides a stable endpoint.

### Why not NodePort?

NodePort exposes the Service through a port on the worker nodes.

Example:

`<node-ip>:30080`
→ Service
→ Backend Pods

NodePort does not automatically mean public access; subnet routing, security groups and other network controls still matter. However, it creates an unnecessary node-level entry point for our backend.

### Why not LoadBalancer?

LoadBalancer is normally used when a Service needs an external/cloud load-balancer entry point.

For our architecture, the backend does not need to be directly exposed externally. The frontend will eventually be the externally accessible component.

Therefore:

Backend → `ClusterIP` ✅

Frontend → external LoadBalancer/Ingress architecture later.

---

## 7. ClusterIP Is Not the Pod IP

If Kubernetes creates:

`backend-service → ClusterIP 10.100.30.15`

that IP represents the Service, not a backend Pod.

The Service can route:

`10.100.30.15:8080`
→ Backend Pod 1 `:8000`

or:

`10.100.30.15:8080`
→ Backend Pod 2 `:8000`

If one Pod dies and another is created, the frontend still uses the same Service name.

This provides stable service discovery and load distribution.

---

## 8. Namespace

All backend resources are created inside the project namespace.

Terraform creates:

`kubernetes_namespace.dojo`

and other resources use:

`kubernetes_namespace.dojo.metadata[0].name`

`metadata[0]` does not mean there are multiple metadata blocks. The Terraform Kubernetes provider represents the nested `metadata` block as a collection, so `[0]` accesses its first/only element.

If:

`var.project = "dojo-dev"`

then:

`kubernetes_namespace.dojo.metadata[0].name`

returns:

`dojo-dev`

The same namespace value is then reused by the Secret, ConfigMap and Services.

---

## 9. Understanding `spec[0]` and `port[0]`

The same Terraform provider pattern is used with the Service.

`kubernetes_service.frontend_service.spec[0]`

means:

"Access the first/only Service spec block."

Then:

`spec[0].cluster_ip`

returns the ClusterIP automatically assigned by Kubernetes.

For example:

`cluster_ip = 10.100.45.23`

We did not manually define this IP. Kubernetes assigned it when the Service was created.

Similarly:

`spec[0].port[0].port`

accesses the first/only Service port block and returns the configured Service port.

For example:

`port = 80`

Therefore Terraform can dynamically construct:

`http://10.100.45.23:80`

without manually knowing the ClusterIP.

---

## 10. Backend ConfigMap and Secret

Before creating Kubernetes environment variables, we inspected the actual application code.

This is the important real-world approach:

Application code → identify required variables → classify sensitive/non-sensitive → create ConfigMap/Secret → inject into Pod.

Environment variables should not be guessed from Kubernetes YAML alone.

### Application configuration discovered from `config.py`

The Flask application reads:

- `SECRET_KEY`
- `DATABASE_URL`
- `FLASK_DEBUG`
- `MAX_QUIZ_QUESTIONS`
- `PASS_THRESHOLD`
- `QUIZ_SESSION_TTL_MINUTES`
- `LEADERBOARD_DEFAULT_LIMIT`

`__init__.py` additionally reads:

- `ALLOWED_ORIGINS`

The application uses `os.getenv()` to read these values at runtime.

---

## 11. DATABASE_URL

The Flask application does not build the database connection from separate DB variables.

It uses:

`DATABASE_URL`

This is the complete PostgreSQL connection string.

Conceptually:

`postgresql://username:password@host:5432/database`

Therefore the database name, host, port, username and password can all be represented inside `DATABASE_URL`.

Because it contains credentials, `DATABASE_URL` should be treated as sensitive and stored in a Kubernetes Secret.

---

## 12. DB_* Variables

The migration script is different.

`migrate.sh` explicitly expects:

- `DB_HOST`
- `DB_PORT`
- `DB_USERNAME`
- `DB_PASSWORD`
- `DB_NAME`

The script uses these values with `psql` to connect directly to PostgreSQL.

Therefore these variables are required when we execute the migration script, even though the Flask application itself primarily uses `DATABASE_URL`.

Current design:

Application → `DATABASE_URL`

Migration script → `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`

---

## 13. SECRET_KEY

`SECRET_KEY` is an application-level cryptographic secret.

It is NOT the password used to authenticate to PostgreSQL.

`DB_PASSWORD` → authenticates against the database.

`DATABASE_URL` → provides the database connection information.

`SECRET_KEY` → protects application security mechanisms such as Flask session/security signing.

Therefore `SECRET_KEY` belongs in a Kubernetes Secret.

---

## 14. ALLOWED_ORIGINS

`ALLOWED_ORIGINS` is used by Flask-CORS.

The backend reads it and configures which browser origins are allowed to make requests.

Our Terraform currently constructs it from the frontend Service:

`http://${frontend ClusterIP}:${frontend Service port}`

For example:

`http://10.100.45.23:80`

Terraform obtains:

`spec[0].cluster_ip`
→ Kubernetes-generated frontend Service ClusterIP

and:

`spec[0].port[0].port`
→ frontend Service port

and combines them into the allowed origin.

This is application-level CORS configuration, not Kubernetes service discovery.

Later, when the frontend is exposed through a real domain such as `https://dojo.example.com`, `ALLOWED_ORIGINS` should use that browser-facing origin instead.

---

## 15. ConfigMap vs Secret

ConfigMap → normal application configuration.

Examples:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `ALLOWED_ORIGINS`
- `FLASK_DEBUG`
- `MAX_QUIZ_QUESTIONS`
- `PASS_THRESHOLD`

Secret → sensitive values.

Examples:

- `DB_PASSWORD`
- `DB_USERNAME`
- `SECRET_KEY`
- `DATABASE_URL`

The distinction is based on sensitivity and application usage.

---

## 16. Secret Type: Opaque

The backend Secret uses:

`type = "Opaque"`

`Opaque` means this is a generic Kubernetes Secret containing arbitrary key/value application data.

It is appropriate for values such as:

- Database credentials
- Application secret keys
- API keys
- Connection strings

Other specialized Kubernetes Secret types include:

- `kubernetes.io/tls` → TLS certificates/private keys
- `kubernetes.io/dockerconfigjson` → container registry credentials
- `kubernetes.io/basic-auth` → basic authentication credentials
- `kubernetes.io/ssh-auth` → SSH private key authentication

`Opaque` does not mean "extra encryption". It identifies the Secret as generic application secret data.

---

## 17. Environment Variable Mapping

The Deployment consumes the Kubernetes resources using:

ConfigMap:

`configMapKeyRef`

Secret:

`secretKeyRef`

Example:

`DB_HOST`
→ backend-config
→ DB_HOST

`DB_PASSWORD`
→ backend-secret
→ DB_PASSWORD

The runtime flow is:

Application code
→ expects environment variable
→ Kubernetes ConfigMap/Secret
→ Deployment injects variable into Pod
→ application reads it with `os.getenv()`

---

## 18. Resource Requests and Limits

Current backend configuration:

Requests:

- CPU: `250m`
- Memory: `256Mi`

Limits:

- CPU: `500m`
- Memory: `512Mi`

Requests tell Kubernetes approximately what resources the Pod needs for scheduling.

Limits define the maximum CPU/memory resources the container can consume.

Practical example:

A backend Pod requesting `256Mi` memory tells Kubernetes:

"Schedule me on a node with enough available capacity for this requested amount."

The `512Mi` limit prevents the container from consuming unlimited memory.

---

## 19. Readiness Probe

Current probe:

`GET /health` on port `8000`

The application has a `/health` endpoint.

It performs:

`SELECT 1`

against the database.

If successful:

`HTTP 200 → healthy`

If database connectivity fails:

`HTTP 503 → unhealthy`

Readiness answers:

"Should Kubernetes send traffic to this Pod?"

If readiness fails, Kubernetes keeps the Pod out of Service traffic.

---

## 20. Liveness Probe

The liveness probe also checks:

`GET /health` on port `8000`

Liveness answers:

"Is this container still functioning, or should Kubernetes restart it?"

This is different from readiness:

Readiness → remove Pod from traffic.

Liveness → potentially restart the container.

---

## 21. Startup Probe

We currently have not added a startup probe.

A startup probe is useful when an application takes a long time to initialize.

It gives the application time to start before Kubernetes begins enforcing the normal liveness/readiness behavior.

For this relatively simple backend, it is not necessarily required. If startup becomes slow because of migrations, heavy initialization or other startup work, a startup probe can be added later.

---

## 22. Dockerfile and Runtime

The backend Dockerfile:

- Uses Python 3.11 slim
- Installs PostgreSQL client/development dependencies
- Installs Python dependencies
- Copies application code
- Exposes port `8000`
- Starts Gunicorn on `0.0.0.0:8000`

The Dockerfile contains `migrate.sh`, but:

`RUN chmod +x migrate.sh`

only makes the script executable.

It does NOT execute the migration script.

The current container startup command is:

`gunicorn --bind 0.0.0.0:8000 run:app`

`run.py` creates the Flask application using:

`app = create_app()`

Therefore migrations are not automatically executed merely because `migrate.sh` exists in the image.

---

## 23. Migration Strategy Later

`migrate.sh`:

- Initializes migrations if required
- Creates migrations
- Runs `flask db upgrade`
- Handles migration conflicts
- Checks whether seed data is required
- Seeds the database when appropriate

For the future GitHub Actions/Kubernetes deployment pipeline, migrations should preferably run as a separate migration step/Job before updating the backend Deployment.

Target flow:

Build image
→ Push image to ECR
→ Run migration using the same backend image
→ Migration succeeds
→ Update backend Deployment
→ New Pods start
→ Readiness probe passes
→ Traffic moves to the new Pods

This avoids having multiple backend replicas simultaneously trying to modify the database schema.

---

## 24. Final Backend Flow

The complete backend architecture is:

Namespace
→ Backend Secret + ConfigMap
→ Backend Deployment
→ Backend Pods
→ Backend ClusterIP Service
→ RDS

Runtime:

Frontend
→ `backend-service:8080`
→ ClusterIP
→ Backend Pod `:8000`
→ `/health`
→ RDS

Configuration:

ConfigMap → non-sensitive configuration

Secret → sensitive configuration

Application code → reads environment variables

Terraform → creates and connects all these resources dynamically

This approach gives us a repeatable infrastructure-as-code deployment and keeps the backend internal while allowing Kubernetes to manage Pod availability and service discovery.