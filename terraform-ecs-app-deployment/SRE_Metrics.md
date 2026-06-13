# Task 17 – SRE Metrics Understanding

## 1. What are the four Google SRE golden signals? Give one example of each for the two-tier app you deployed.

Google SRE defines four golden signals that help measure the health of an application from a user perspective.

### Latency

Latency measures how long it takes for a request to be processed and returned to the user.

**Example from my project Student Portal:**

When a user logs into the Student Portal, the login page should load quickly. If it takes 5-10 seconds to log in, latency is high even though the application is still running.

---

### Traffic

Traffic measures the demand on the application.

**Example in SP project:**

The number of requests reaching our Application Load Balancer (ALB) and ECS service. During normal usage I may receive a small number of requests, but during heavy usage traffic can increase significantly.

---

### Errors

Errors measure failed requests.

**Example:**

While troubleshooting ECS deployments, my app returned HTTP 500 errors due to application startup failures and incorrect Python imports and db initialization errors. These errors directly affected users even though infrastructure resources were running.

---

### Saturation

Saturation measures how close the system is to its limits.

**Example:**

If ECS tasks are running at 90% CPU or memory utilization, the application is approaching capacity and may require Auto Scaling to maintain performance. It helps to predicts future failures before users reports an issue

---

## 2. Why is measuring only container uptime and CPU/memory not enough to understand user experience?

Container uptime and resource utilization only tell me whether the infrastructure is running.

During my learning, there were situations where:

* ECS tasks were running
* CPU and memory looked healthy
* ALB health checks were passing

However, users could not access the application because the container failed during startup due to incorrect imports. I have added the troubleshooting steps and rca in troubleshooting.md file

This showed me that healthy infrastructure does not always mean a healthy application.

To understand the real user experience, I also need to monitor:

* Request latency
* Error rates
* Traffic
* Application logs
* ALB metrics

---

## 3. In the ALB metrics, what does a spike in 5xx response codes tell you that a green health check does not?

A green health check only confirms that the target is responding to the configured health check endpoint.

A spike in 5xx errors indicates that users are receiving server-side errors even though the target may still appear healthy.

**Example:**

The ECS task could start successfully and pass health checks, but if the application encountered database connection issues or code errors, users would receive HTTP 500 errors. When I registered in the app, on submission it throwed 500 error due to DB initilaization is not done through gunicorn. 

In this situation:

```text
Health Check = Green ✅
User Requests = Failing ❌
```

Therefore, ALB 5xx metrics provide a better indication of actual user-facing problems.

---

## 4. Where in the AWS Console can you find 5xx counts for your ALB? What time range would you check if a user reported an issue?

I can find ALB 5xx metrics in:

```text
CloudWatch
→ Metrics
→ ApplicationELB
→ HTTPCode_ELB_5XX_Count
```

or

```text
EC2
→ Load Balancers
→ Monitoring
→ HTTPCode_ELB_5XX_Count
```

If a user reports an issue, I would check the time period around the reported incident.

For example, if the issue occurred at 2:00 PM, I would investigate:

```text
1:45 PM to 2:15 PM
```

This helps correlate:

* ALB 5xx spikes
* ECS task failures
* Application logs
* Deployment activities

and identify the root cause more quickly.

---

## Key Learning

While working on this Student Portal project, I learned that monitoring should focus on user experience and not just infrastructure health. Metrics such as latency, traffic, errors, and saturation provide a much clearer picture of how the application is performing from the user's perspective.

---