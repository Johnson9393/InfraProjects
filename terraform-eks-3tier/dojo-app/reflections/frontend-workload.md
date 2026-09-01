# Frontend Kubernetes Deployment — Learning Notes

## 1. Purpose

The frontend is the user-facing application of the Dojo project.

Current architecture:

User → Frontend → Backend Service → Backend Pods → RDS

The frontend will eventually be exposed externally, while communication from the frontend to the backend remains internal through the Kubernetes backend Service.

---

## 2. Frontend Deployment

The frontend Deployment defines:

- Frontend container image
- Number of replicas
- Pod labels
- Container port
- Runtime configuration
- Resource requests/limits
- Readiness probe
- Liveness probe

Current configuration:

- Replicas: `2`
- Container port: `3000`
- Frontend Service port: `80`
- Frontend Service target port: `80`

The important distinction is that the application itself is actually listening on port `80`.

---

## 3. Frontend Dockerfile and Port

The frontend Dockerfile uses:

`EXPOSE 80`

The `server.js` confirms the actual runtime port:

`const PORT = process.env.PORT || 80;`

and starts Express with:

`app.listen(PORT, '0.0.0.0', ...)`

Therefore the frontend application listens on:

`0.0.0.0:80`

The Dockerfile and `server.js` are the authoritative places to verify the application's actual listening port.

Note: The current Deployment has `containerPort: 3000`, while the application actually listens on `80`. This should eventually be corrected to `containerPort: 80` so that the Kubernetes configuration accurately represents the application.

---

## 4. Frontend Service

The frontend Service currently uses:

`type = "ClusterIP"`

`port = 80`

`targetPort = 80`

So internally:

Frontend Service `:80`
→ Frontend Pod `:80`

The Service selector is:

`app = frontend`

and the Pod template has:

`app = frontend`

Therefore the Service discovers the frontend Pods through this matching label.

For the final external architecture, the frontend will need an external entry point such as an AWS LoadBalancer/Ingress rather than relying only on ClusterIP.

---

## 5. Frontend Environment Variables

The Terraform `frontend_config` creates:

- `APP_VERSION`
- `APP_NAME`
- `BACKEND_URL`

These are exposed to the frontend container through `configMapKeyRef`.

The mapping is:

`APP_VERSION`
→ `frontend-config`
→ `APP_VERSION`

`APP_NAME`
→ `frontend-config`
→ `APP_NAME`

`BACKEND_URL`
→ `frontend-config`
→ `BACKEND_URL`

Unlike the backend, the frontend does not currently require database credentials or a Kubernetes Secret.

---

## 6. BACKEND_URL

The frontend needs to know where to send API requests.

Terraform currently constructs:

`http://${kubernetes_service.backend_service.spec[0].cluster_ip}:${kubernetes_service.backend_service.spec[0].port[0].port}`

For example, if the backend Service receives:

`ClusterIP = 10.100.30.15`

and:

`Service port = 8080`

Terraform produces:

`http://10.100.30.15:8080`

This value becomes:

`BACKEND_URL`

The frontend's `server.js` reads:

`process.env.BACKEND_URL`

and uses it as the target for `/api` requests.

Therefore:

Browser → Frontend → `/api` → Frontend Express proxy → `BACKEND_URL` → Backend Service

---

## 7. Frontend Proxy

The frontend `server.js` uses:

`http-proxy-middleware`

for API requests:

`app.use('/api', createProxyMiddleware(...))`

This means the browser does not need to directly communicate with the backend Service.

Example:

Browser:

`http://frontend/api/topics`

Frontend Express:

`/api/topics`

Proxies to:

`BACKEND_URL + /api/topics`

Backend:

`backend-service:8080`

This keeps backend communication internal to the Kubernetes environment.

---

## 8. Frontend Health Endpoint

The frontend provides:

`GET /health`

and returns:

`200 healthy`

This endpoint is used by Kubernetes for readiness and liveness checks.

Current probes check port `80`:

`/health → port 80`

This matches the actual Express application listening port.

---

## 9. Readiness Probe

The readiness probe checks:

`GET /health :80`

Purpose:

"Is this frontend Pod ready to receive traffic?"

If the probe succeeds, Kubernetes can send Service traffic to the Pod.

If it fails, Kubernetes temporarily removes the Pod from Service endpoints.

---

## 10. Liveness Probe

The liveness probe also checks:

`GET /health :80`

Purpose:

"Is the frontend container still functioning?"

If the container becomes unhealthy according to the configured thresholds, Kubernetes can restart it.

---

## 11. Resource Requests and Limits

Current frontend configuration:

Requests:

- CPU: `250m`
- Memory: `256Mi`

Limits:

- CPU: `500m`
- Memory: `512Mi`

Requests help Kubernetes schedule the Pod with sufficient resources.

Limits prevent the container from consuming unlimited CPU or memory.

---

## 12. Frontend Configuration Flow

The overall flow is:

Terraform
→ `frontend_config`
→ Kubernetes ConfigMap
→ Frontend Deployment
→ environment variables
→ Express application

The important runtime variables are:

`APP_NAME`

`APP_VERSION`

`BACKEND_URL`

The frontend does not currently use database configuration because database access belongs to the backend.

---

## 13. Final Frontend Flow

Current intended architecture:

User
→ Frontend
→ Frontend Service
→ Frontend Pods
→ Backend Service (ClusterIP)
→ Backend Pods
→ RDS

The frontend is responsible for the user-facing application and forwarding API requests.

The backend remains an internal Kubernetes service.

Later, the frontend Service can be changed/connected to an external AWS LoadBalancer or Ingress so users can access the application from outside the cluster.