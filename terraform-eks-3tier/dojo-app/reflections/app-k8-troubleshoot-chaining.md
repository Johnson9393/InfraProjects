# Kubernetes / EKS Troubleshooting Chain

This is the practical troubleshooting flow used for the Dojo 3-tier application.

The main mental model is:

DNS → ALB → Ingress → Service → EndpointSlice → Pod → Application → Database

When troubleshooting, move through these layers from the outside toward the application.

---

## 1. DNS — Does the Domain Resolve?

### Command

dig +short dojo.infralabx.space

### What are we checking?

We are asking DNS:

> "What IP address(es) does this domain resolve to?"

`dig` is a DNS lookup/debugging command.

`+short` tells `dig` to show only the useful answer instead of all DNS details.

Example:

98.90.145.76
54.81.202.244

If IP addresses are returned:

- DNS resolution is working.
- The Route53 record is resolving to the ALB.

If nothing is returned:

- Check the Route53 record.
- Check that the domain/subdomain exists.
- Check that the record points to the correct ALB.

### Mental model

Domain name → DNS → ALB address

---

## 2. HTTPS / HTTP — Can We Reach the ALB?

### Command

curl -I https://dojo.infralabx.space

`curl` makes an HTTP/HTTPS request.

`-I` means:

> "Show only the HTTP response headers."

This is useful because we mainly want the HTTP status code and server response.

Example:

HTTP/2 503
server: awselb/2.0

This tells us:

- DNS resolved.
- The request reached the AWS Load Balancer.
- The ALB returned an HTTP response.
- `503` means the ALB currently has no healthy backend target to serve the request.

At this point DNS is working, so move deeper into Kubernetes.

---

# 3. Ingress — Is the ALB Being Created?

### Command

kubectl get ingress -n dojo

Example:

NAME           CLASS   HOSTS                  ADDRESS
dojo-ingress   alb     dojo.infralabx.space   k8s-dojo-....elb.amazonaws.com

Important fields:

- `CLASS = alb` → AWS Load Balancer Controller should manage this Ingress.
- `HOSTS` → domain configured in the Ingress.
- `ADDRESS` → ALB created for this Ingress.

### Problem: ADDRESS is empty

Example:

dojo-ingress   alb   dojo.infralabx.space   <empty>

This means the Ingress exists, but an ALB has not been provisioned.

### Check AWS Load Balancer Controller

kubectl get pods -n kube-system | grep aws-load-balancer

If no controller Pods exist, the AWS Load Balancer Controller is probably not installed/running.

For this project, the controller is managed by Terraform in:

EKS/k8s-services

So the troubleshooting path is:

Ingress exists
→ ALB address empty
→ check AWS Load Balancer Controller
→ install/apply k8s-services Terraform if required.

---

# 4. Ingress — If ALB Exists but Returns 503

If:

- DNS resolves
- ALB exists
- HTTPS reaches the ALB
- ALB returns `503`

then move inside Kubernetes.

The next question is:

> "Does the Kubernetes Service actually have Pods behind it?"

---

# 5. Service → EndpointSlice — Does the Service Have Pod Destinations?

### Command

kubectl get endpoints -n dojo

Example of a problem:

backend-service    <none>
frontend-service   <none>

`<none>` means:

> The Service currently has no Pod destinations.

Modern Kubernetes internally uses EndpointSlices, so the preferred newer command is:

kubectl get endpointslices -n dojo

### Mental model

Service = stable front door

EndpointSlice = current list of Pod destinations behind that front door

Example:

Service
→ EndpointSlice
→ 10.0.x.x:8000
→ 10.0.x.x:8000

If the Service has no endpoints, Kubernetes has no healthy matching Pod destination to send traffic to.

Therefore:

Service has `<none>`
→ investigate Pods and Service selectors.

---

# 6. Service Selector → Pod Labels

A Service selects Pods using labels.

Example Service selector:

app=backend

Check Pod labels:

kubectl get pods -n dojo --show-labels

If the backend Pods do not have:

app=backend

then the Service selector cannot find them.

Result:

Service
→ selector does not match Pods
→ no EndpointSlice destinations
→ ALB has no usable backend
→ request can result in 503.

### Mental model

Service selector:

"Give me Pods with app=backend."

Pod label:

"app=backend"

They must match.

---

# 7. Pod Status — What State Is the Pod In?

### Command

kubectl get pods -n dojo

Example:

NAME                       READY   STATUS    RESTARTS
backend-xxxxx              1/1     Running   0
frontend-xxxxx             1/1     Running   0

For a healthy application Pod we generally want:

READY = 1/1
STATUS = Running

If the Pod is not healthy, the `STATUS` tells us which direction to investigate.

---

# 8. Pod Status: Pending

Example:

backend-xxxxx    0/1    Pending

`Pending` means Kubernetes has created the Pod object, but the Pod has not successfully started running on a node yet.

Common causes include:

- No suitable node available.
- Insufficient CPU or memory.
- Node selector/affinity cannot be satisfied.
- Taints/tolerations prevent scheduling.
- PersistentVolume/PVC problems.
- Image-related preparation problems before the container starts.

### First troubleshooting command

kubectl describe pod <pod-name> -n dojo

Look at the Events section.

For example:

FailedScheduling

This usually points toward a scheduling/resource/node problem.

### Mental model

Deployment creates Pod
→ Kubernetes Scheduler tries to place Pod on a node
→ cannot place it
→ Pod remains Pending

---

# 9. Pod Status: ContainerCreating

Example:

backend-xxxxx    0/1    ContainerCreating

The Pod has been scheduled onto a node, but the container is still being prepared.

Possible things happening:

- Container image is being pulled.
- Container filesystem is being prepared.
- Volumes are being mounted.
- Networking/container setup is occurring.

If it stays here for too long:

kubectl describe pod <pod-name> -n dojo

Check Events for the actual reason.

---

# 10. Pod Status: ImagePullBackOff

Example:

backend-xxxxx    0/1    ImagePullBackOff

This means Kubernetes tried to pull the container image and failed.

`BackOff` means Kubernetes is waiting progressively longer before retrying.

We experienced this when the ECR image URI was malformed.

Typical causes:

- Wrong ECR repository URL.
- Wrong image tag.
- Image does not exist.
- ECR authentication/permission problem.
- Node cannot reach ECR.
- Wrong AWS region/account/repository.

### Useful commands

kubectl describe pod <pod-name> -n dojo

Look at Events.

You may see messages such as:

Failed to pull image

or

pull access denied

or

not found

### Mental model

Pod scheduled
→ Kubernetes asks container runtime to pull image
→ image pull fails
→ retry
→ retry fails
→ ImagePullBackOff

---

# 11. Pod Status: CrashLoopBackOff

Example:

backend-xxxxx    0/1    CrashLoopBackOff

This is different from ImagePullBackOff.

Here the image was successfully started, but the container keeps crashing.

Mental model:

Container starts
→ application crashes/exits
→ Kubernetes restarts it
→ application crashes again
→ repeated failures
→ CrashLoopBackOff

### First command

kubectl logs <pod-name> -n dojo --previous

`--previous` is important when the container has already crashed and restarted.

It asks Kubernetes:

> "Show me the logs from the previous container instance that crashed."

This often exposes the actual application error.

Examples of things we encountered:

- Incorrect database host.
- Incorrect database URL/dialect.
- Application startup failure.
- Configuration/environment-variable problems.

---

# 12. Pod Status: Running but Not Ready

Example:

backend-xxxxx    0/1    Running

This is an important state.

`Running` does NOT necessarily mean:

> "The application is ready to receive traffic."

It only means the container is running.

The Pod can still be:

0/1 Running

because its readiness check has not succeeded.

If a Pod is not Ready, Kubernetes may keep it out of the Service's usable endpoints.

Therefore:

Running + not Ready
→ check readiness/probes
→ check application
→ check logs.

---

# 13. Pod Status: Completed / Error

### Completed

Usually means the container finished successfully.

This is normal for things such as:

- Jobs
- migration tasks
- one-time scripts

It is usually NOT what we expect from a continuously running frontend/backend Deployment.

### Error

Usually means the container terminated unsuccessfully.

Check:

kubectl logs <pod-name> -n dojo

and:

kubectl describe pod <pod-name> -n dojo

---

# 14. Deployment — Is Kubernetes Creating the Pods?

If there are no Pods:

kubectl get pods -n dojo

No resources found

Then check the Deployments:

kubectl get deployments -n dojo

A Deployment is responsible for maintaining the desired number of application Pods.

Mental model:

Deployment
→ creates/manages ReplicaSet
→ ReplicaSet creates Pods
→ Pods run the application

If the Deployment itself is missing, the application workload has not been deployed.

---

# 15. Service Port → Container Port

Suppose the backend Service is:

port: 8080
targetPort: 8000

This means:

ALB/Ingress
→ Service port 8080
→ Pod/container port 8000

The application inside the container must actually listen on the expected port.

If Kubernetes networking looks correct but traffic still fails, inspect the Pod:

kubectl describe pod <pod-name> -n dojo

Also check application logs:

kubectl logs <pod-name> -n dojo

A common failure is:

Service sends traffic to port 8000
but application is actually listening on another port.

---

# 16. Application Layer — Check the Application Logs

### Command

kubectl logs <pod-name> -n dojo

At this point Kubernetes may be completely healthy:

- Pod is Running.
- Pod is Ready.
- Service has endpoints.
- Ports are correct.

But the application itself may still be failing.

Logs can reveal:

- Application startup errors.
- Database connection errors.
- Invalid configuration.
- Missing environment variables.
- Application exceptions.
- Dependency failures.

---

# 17. Database Connectivity

For the backend, the next dependency is PostgreSQL/RDS.

The backend health endpoint used by this application is:

/health

The documented healthy response is:

{"status":"healthy","database":"connected"}

The important point is that the application can be running while its database connection is broken.

Mental model:

Backend Pod
→ application
→ DATABASE_URL / DB configuration
→ RDS PostgreSQL

If the database connection fails, investigate:

- DB host
- DB port
- DB name
- username/password
- DATABASE_URL
- Security Group/network connectivity
- RDS availability

We previously encountered incorrect database configuration, including:

- DB host set incorrectly
- `postgres://` instead of `postgresql://`

---

# 18. Migration / Job Troubleshooting

Database migrations are run using a Kubernetes Job.

A Job is different from a Deployment.

Deployment:

"Keep this application running."

Job:

"Run this task until it succeeds."

Check Jobs:

kubectl get jobs -n dojo

Check Pods created by the Job:

kubectl get pods -n dojo

If the migration Job fails:

kubectl logs <migration-pod> -n dojo

### Important: Job templates are immutable

If a Job already exists, changing its image, command, or environment variables and running:

kubectl apply -f migration.yaml

may fail because the Job's Pod template cannot be changed.

The usual approach is:

kubectl delete job backend-migration -n dojo

Then recreate it:

kubectl apply -f migration.yaml

---

# 19. ImagePullBackOff vs CrashLoopBackOff

These two are easy to confuse.

### ImagePullBackOff

Image cannot be pulled.

Flow:

Pod scheduled
→ pull image
→ pull fails
→ retry
→ ImagePullBackOff

Investigate:

kubectl describe pod <pod-name> -n dojo

Focus on image URI, tag, ECR, permissions, networking.

### CrashLoopBackOff

Image was pulled and container started, but application keeps crashing.

Flow:

Image pulled
→ container starts
→ application crashes
→ restart
→ crashes again
→ CrashLoopBackOff

Investigate:

kubectl logs <pod-name> -n dojo --previous

Focus on application/configuration/runtime errors.

---

# 20. Complete Troubleshooting Chain

Use this order instead of randomly running commands:

DNS
↓
dig +short dojo.infralabx.space
↓
Does DNS resolve?
↓
HTTPS / ALB
↓
curl -I https://dojo.infralabx.space
↓
Does the request reach the ALB?
↓
Ingress
↓
kubectl get ingress -n dojo
↓
Does the Ingress have an ALB ADDRESS?
↓
If not → AWS Load Balancer Controller
↓
Service
↓
kubectl get endpoints -n dojo
or
kubectl get endpointslices -n dojo
↓
Does the Service have Pod destinations?
↓
If not → check Pod labels vs Service selector
↓
Pods
↓
kubectl get pods -n dojo
↓
What is the Pod STATUS?
↓
Pending → scheduling/resources/node/events
ContainerCreating → describe/events
ImagePullBackOff → image/ECR/pull problem
CrashLoopBackOff → previous container logs
Running but 0/1 → readiness/application problem
Running 1/1 → continue deeper
↓
Pod ports
↓
Does Service targetPort match what the application listens on?
↓
Application
↓
kubectl logs <pod-name> -n dojo
↓
Is the application itself healthy?
↓
Database
↓
Is the backend connected to PostgreSQL/RDS?
↓
Migration
↓
Are database migrations completed successfully?

---

# 21. The Core Mental Model

When an external request fails, think from outside → inside:

Internet
  ↓
DNS
  ↓
ALB
  ↓
Ingress
  ↓
Service
  ↓
EndpointSlice
  ↓
Pod
  ↓
Container/Application
  ↓
Database

Each layer answers one question:

DNS
→ "Where is this domain?"

ALB
→ "Can I receive the external request?"

Ingress
→ "Where should this host/path go?"

Service
→ "Which application should receive this traffic?"

EndpointSlice
→ "Which actual Pod IPs can receive it?"

Pod
→ "Is the application container running and ready?"

Application
→ "Is the application itself working?"

Database
→ "Can the application reach its dependency?"

This prevents random troubleshooting.

Always identify the first layer that is broken, then move deeper only after that layer is confirmed healthy.