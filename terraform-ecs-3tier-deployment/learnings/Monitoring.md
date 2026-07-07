## Monitoring Interview Notes

### Q1. Why not create a CloudWatch Alarm directly on application logs?

**Answer:**

CloudWatch Alarms can monitor only **CloudWatch Metrics**, not raw log events.

A **CloudWatch Log Metric Filter** converts matching log patterns into CloudWatch Custom Metrics. These custom metrics can then be visualized in Dashboards and monitored using CloudWatch Alarms and Amazon SNS.

Flow:

```text
Application Logs
        │
        ▼
Log Metric Filter
        │
        ▼
CloudWatch Custom Metric
        │
        ▼
Dashboard / Alarm / SNS
```

---

### Q2. What is the difference between Infrastructure Monitoring and Application Monitoring?

**Infrastructure Monitoring**

Monitors AWS resources.

Examples:

- ECS CPU
- ECS Memory
- ALB Request Count
- ALB Response Time

Answers:

> Is my infrastructure healthy?

---

**Application Monitoring**

Monitors application behavior.

Examples:

- Request Latency
- HTTP Request Count
- Backend 5XX Count
- Backend Error Count
- Proxy Errors

Answers:

> Is my application healthy?

---

### Q3. What is Embedded Metric Format (EMF)?

**Answer:**

EMF is a CloudWatch feature that allows an application to publish custom metrics directly from the application code.

Examples:

- RequestDurationOverall
- RequestDuration
- HttpRequestCount

CloudWatch automatically converts EMF logs into CloudWatch Custom Metrics.

Flow:

```text
Application
      │
      ▼
EMF Logs
      │
      ▼
CloudWatch Custom Metrics
```

---

### Q4. What is a CloudWatch Log Metric Filter?

**Answer:**

A Log Metric Filter scans CloudWatch Logs for matching patterns and converts them into CloudWatch Custom Metrics.

Examples:

- status >= 500 → Backend5xxCount
- level = ERROR → BackendErrorCount
- "Proxy error" → FrontendProxyErrorCount

---

### Q5. When should you use EMF and when should you use Log Metric Filters?

**Use EMF**

- Request Latency
- Request Count
- Business Metrics
- Custom Application Metrics

**Use Log Metric Filters**

- HTTP 5XX Errors
- ERROR Logs
- Proxy Failures
- Exception Counts

---

### Q6. Does EMF automatically create Dashboards and Alarms?

**Answer:**

No.

EMF only creates **CloudWatch Custom Metrics**.

Dashboards, CloudWatch Alarms and SNS notifications must be created separately.

---

### Q7. What is the complete monitoring flow in this project?

```text
Application
      │
      ├──────── AWS Metrics
      │
      ├──────── EMF Metrics
      │
      └──────── Application Logs
                    │
                    ▼
          Log Metric Filters
                    │
                    ▼
         CloudWatch Custom Metrics
                    │
                    ▼
          CloudWatch Dashboard
                    │
                    ▼
          CloudWatch Alarms
                    │
                    ▼
               Amazon SNS
                    │
                    ▼
            Email Notification
```

---

### Q8. What did you validate during load testing?

- Verified CloudWatch Dashboard updates in real time.
- Verified ECS CPU and Memory utilization.
- Verified ALB Request Count and Response Time.
- Verified CloudWatch Alarm transitioned from **OK → ALARM → OK**.
- Verified Amazon SNS email notifications for both ALARM and recovery.
- Correlated k6 load with CloudWatch metrics to identify infrastructure bottlenecks.

---

---

## Log Metric Filters

CloudWatch Log Metric Filters convert matching application log patterns into CloudWatch Custom Metrics. These metrics can then be used in CloudWatch Dashboards, CloudWatch Alarms and Amazon SNS notifications.

### Backend5xxCount

Purpose:

Counts the number of HTTP 5XX responses returned by the backend application.

Example:

```json
{
  "status": 500
}
```

CloudWatch Metric:

```text
Backend5xxCount = 1
```

Use Case:

- Detect server-side failures.
- Monitor APIs returning HTTP 500, 502, 503 or 504 responses.

---

### BackendErrorCount

Purpose:

Counts application logs written with **ERROR** log level.

Example:

```json
{
  "levelname": "ERROR",
  "message": "Database connection failed"
}
```

CloudWatch Metric:

```text
BackendErrorCount = 1
```

Use Case:

- Detect application exceptions.
- Monitor internal application failures.
- Identify issues that may not always return HTTP 5XX responses.

---

### FrontendProxyErrorCount

Purpose:

Counts frontend proxy failures while forwarding requests to the backend.

Example:

```text
Proxy error: connect ECONNREFUSED backend:8000
```

CloudWatch Metric:

```text
FrontendProxyErrorCount = 1
```

Use Case:

- Backend service unavailable.
- Backend timeout.
- Network connectivity issues between frontend and backend.
- Proxy configuration problems.

---

## Difference Between the Three Metrics

| Metric | What it Monitors | Example |
|---------|------------------|---------|
| **Backend5xxCount** | HTTP 5XX responses returned to clients | API returns **500 Internal Server Error** |
| **BackendErrorCount** | Internal application ERROR logs | Database connection failure logged as **ERROR** |
| **FrontendProxyErrorCount** | Frontend communication failures with backend | Frontend cannot reach backend service |

---

---

## Understanding EMF Metrics and Dimensions

### Metric vs Dimension

A **Metric** represents **what is being measured**, while a **Dimension** identifies **which resource or category the metric belongs to**.

Examples:

| Metric | Dimension |
|--------|-----------|
| CPUUtilization | ClusterName, ServiceName |
| MemoryUtilization | ClusterName, ServiceName |
| RequestDuration | Endpoint, Method, StatusClass |
| HttpRequestCount | Endpoint, Method, StatusClass |
| RequestDurationOverall | Service |

---

### Example

Suppose a user sends:

```text
POST /leaderboard
```

The backend returns:

```text
HTTP 500
```

and the request completes in **850 ms**.

CloudWatch EMF publishes:

**Metric**

```text
RequestDuration = 850 ms
```

**Dimensions**

```text
Endpoint    = leaderboard
Method      = POST
StatusClass = 5xx
```

CloudWatch stores the metric together with these dimensions, allowing you to filter and analyze latency for a specific API, HTTP method, and response status.

---

### EMF Metrics Used in This Project

**RequestDurationOverall**

- Overall average response time of the backend service.
- Dimension: `Service = backend`

**RequestDuration**

- Average response time for a specific API.
- Dimensions:
  - Endpoint
  - Method
  - StatusClass

**HttpRequestCount**

- Number of requests received by a specific API.
- Dimensions:
  - Endpoint
  - Method
  - StatusClass

---

### Key Takeaway

Think of it as:

- **Metric → What is being measured?**
- **Dimension → Which resource or request does the metric belong to?**

This allows CloudWatch to drill down from overall service health to individual API performance, making it easier to identify the exact endpoint, HTTP method, or status code causing an issue.
---

## Key Takeaway

These three metrics monitor different layers of the application:

- **Backend5xxCount** → What the **client experiences** (HTTP server errors).
- **BackendErrorCount** → What the **backend application experiences** internally.
- **FrontendProxyErrorCount** → What happens between the **frontend and backend** during request forwarding.

Together, they provide comprehensive application-level monitoring beyond standard AWS infrastructure metrics.