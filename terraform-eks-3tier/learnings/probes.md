# Kubernetes Probes — Liveness, Readiness & Startup

Kubernetes **probes** are health checks that Kubernetes performs on containers to understand whether the application has started correctly, is ready to receive traffic, and is still healthy while running.

The three important probes are:

    Startup Probe
        ↓
    "Has my application finished starting?"

    Readiness Probe
        ↓
    "Am I ready to receive traffic?"

    Liveness Probe
        ↓
    "Am I still alive, or should Kubernetes restart me?"

A simple mental model is:

    STARTUP  → Can the application start?
    READINESS → Can the application receive traffic?
    LIVENESS  → Is the application still healthy?

## Why Do We Need Probes?

A Pod being in `Running` state does NOT necessarily mean the application inside it is actually working.

For example:

    Pod
      ↓
    Container started
      ↓
    Application crashed / stuck / still starting
      ↓
    Pod may still appear Running

Kubernetes needs a way to check the **actual application health**, not just whether the container process exists.

Probes provide that health information.

## 1. Startup Probe

A startup probe checks whether the application has **finished starting successfully**.

Example:

    startupProbe:
      httpGet:
        path: /health
        port: 5000
      failureThreshold: 30
      periodSeconds: 10

This means Kubernetes gives the application time to start before treating it as unhealthy.

For example, suppose our backend needs 60 seconds to start because it has to:

    Start application
        ↓
    Load configuration
        ↓
    Connect to database
        ↓
    Load required data
        ↓
    Start serving requests

During this time, the application may not respond to `/health`.

Without a startup probe, Kubernetes may start checking liveness immediately and incorrectly think the application is broken.

With a startup probe:

    Container starts
         ↓
    Startup probe checks application
         ↓
    Application still starting
         ↓
    Give it more time
         ↓
    Application becomes ready
         ↓
    Startup probe succeeds
         ↓
    Liveness + Readiness checks take over

The startup probe is especially useful for applications that have a **slow startup time**.

## 2. Readiness Probe

The readiness probe answers:

    "Can this Pod receive traffic right now?"

Example:

    readinessProbe:
      httpGet:
        path: /health
        port: 5000
      initialDelaySeconds: 10
      periodSeconds: 10

Suppose we have:

    Backend Service
         ↓
    ┌────┬────┬────┐
    ↓    ↓    ↓
   Pod1 Pod2 Pod3

Now Pod2 has a problem:

    Pod2
      ↓
    Application cannot connect to database
      ↓
    Readiness probe fails

Kubernetes removes Pod2 from the Service's available endpoints.

Traffic becomes:

    Service
      ↓
    Pod1 + Pod3

Pod2 is still running, but it does **not receive normal application traffic**.

This is the main purpose of readiness.

    Readiness SUCCESS
        ↓
    Pod can receive traffic

    Readiness FAILURE
        ↓
    Pod is removed from Service traffic

The container is NOT necessarily restarted just because readiness fails.

This distinction is very important.

## 3. Liveness Probe

The liveness probe answers:

    "Is my application still alive and working?"

Example:

    livenessProbe:
      httpGet:
        path: /health
        port: 5000
      initialDelaySeconds: 30
      periodSeconds: 10

Suppose the backend gets stuck:

    Backend Pod
        ↓
    Application process still exists
        ↓
    But application is completely stuck
        ↓
    Liveness probe fails
        ↓
    Kubernetes considers container unhealthy
        ↓
    Container is restarted

So:

    Liveness FAILURE
        ↓
    Restart container

This is different from readiness:

    Readiness FAILURE
        ↓
    Stop sending traffic

    Liveness FAILURE
        ↓
    Restart container

## Real-World Example

Suppose our EKS application has:

    Frontend
       ↓
    Backend
       ↓
    PostgreSQL RDS

Three backend Pods are running:

    Service
      ↓
    ┌──────┬──────┬──────┐
    ↓      ↓      ↓
   Pod1   Pod2   Pod3

### Situation 1 — Pod is starting

Pod3 has just started and needs 40 seconds to initialize.

    Startup Probe
         ↓
    Application still starting
         ↓
    Don't restart it
         ↓
    Wait
         ↓
    Application starts successfully

This prevents Kubernetes from killing a perfectly healthy application simply because it needs time to start.

### Situation 2 — Pod is running but temporarily unavailable

Pod2 cannot connect to the database.

    Readiness Probe
         ↓
    FAIL
         ↓
    Pod2 removed from Service endpoints
         ↓
    Traffic goes to Pod1 + Pod3

When the database connection works again:

    Readiness Probe
         ↓
    SUCCESS
         ↓
    Pod2 added back to Service endpoints

The Pod does not necessarily need to restart.

### Situation 3 — Application is completely stuck

Pod1's application process is still running, but it is stuck and no longer responds correctly.

    Liveness Probe
         ↓
    FAIL
         ↓
    Kubernetes restarts container
         ↓
    Application starts again
         ↓
    Readiness succeeds
         ↓
    Pod receives traffic again

## How Are Probes Implemented?

The most common method for HTTP applications is:

    httpGet:
      path: /health
      port: 5000

The application needs to expose a health endpoint such as:

    GET /health

For example, the backend could return:

    HTTP 200
    {
      "status": "healthy"
    }

Kubernetes calls that endpoint periodically.

Other probe methods are also available:

    HTTP GET
    TCP Socket
    Command / Exec

For our frontend/backend application, HTTP probes are usually the simplest approach if the applications expose health endpoints.

## Important Probe Settings

Example:

    livenessProbe:
      httpGet:
        path: /health
        port: 5000
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3

Meaning:

    initialDelaySeconds
    → Wait 30 seconds before starting checks.

    periodSeconds
    → Check every 10 seconds.

    timeoutSeconds
    → Give the health check 5 seconds to respond.

    failureThreshold
    → After 3 consecutive failures, consider the probe failed.

These values should be based on how the application actually behaves. They should not be chosen randomly.

## How The Three Probes Work Together

The complete lifecycle is:

    Pod starts
       ↓
    Startup Probe
       ↓
    Application finished starting?
       ↓
      YES
       ↓
    ┌───────────────┐
    ↓               ↓
    Readiness       Liveness
    ↓               ↓
    Receive         Stay
    traffic?        healthy?
    ↓               ↓
   YES             YES
    ↓               ↓
   Traffic       Keep running

If readiness fails:

    Pod
     ↓
    Readiness FAIL
     ↓
    Remove from Service traffic
     ↓
    Fix application
     ↓
    Readiness SUCCESS
     ↓
    Receive traffic again

If liveness fails:

    Pod
     ↓
    Liveness FAIL
     ↓
    Container restart
     ↓
    Startup again
     ↓
    Readiness SUCCESS
     ↓
    Receive traffic

## Very Important Difference

    STARTUP
    "Has the application successfully started?"

    READINESS
    "Can I send traffic to this Pod?"

    LIVENESS
    "Is the application still alive?"

Therefore:

    Startup failure
        → Application cannot successfully start

    Readiness failure
        → Stop sending traffic to the Pod

    Liveness failure
        → Restart the container

## Why We Use All Three

Using all three gives Kubernetes better control over the application lifecycle:

    Startup
       ↓
    Protect slow-starting applications

    Readiness
       ↓
    Protect users from unhealthy/unready Pods

    Liveness
       ↓
    Automatically recover stuck applications

For our EKS project, when we create the frontend and backend Deployment YAMLs, we can add these probes so Kubernetes does not blindly send traffic to a Pod that is still starting or temporarily unhealthy, and can automatically restart a container that becomes permanently stuck.

## Final Mental Model

Think of a restaurant:

    STARTUP
    → "Has the restaurant finished opening?"

    READINESS
    → "Is the restaurant ready to accept customers?"

    LIVENESS
    → "Is the restaurant still functioning?"

So the Kubernetes mental model is:

    Startup  → Start successfully
    Readiness → Receive traffic
    Liveness  → Stay healthy / restart if stuck

**In one sentence: Startup checks whether the application has started, readiness controls whether the Pod receives traffic, and liveness checks whether the application is still healthy enough to keep running.**