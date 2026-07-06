![alt text](screenshots/CPU_Memory.png)

![alt text](screenshots/ALB_Response.png)

![alt text](screenshots/Perf_Logs.png)

![alt text](screenshots/LoadResults.png)



# Performance Testing Guide (k6 + AWS ECS)

## Objective

Validate the performance of the application deployed on AWS ECS using **k6**, observe infrastructure metrics using **CloudWatch Container Insights**, and identify application bottlenecks before enabling Auto Scaling.

---

# Architecture

```
k6
 │
 ▼
Route53
 │
 ▼
Application Load Balancer (ALB)
 │
 ▼
ECS Service (1 Task)
 │
 ▼
Backend Container
 │
 ▼
RDS Database
```

---

# Monitoring Setup

Before running any performance test, open the following AWS Console pages:

### 1. ECS Service

```
ECS
→ Cluster
→ Backend Service
→ Health and Metrics
```

Monitor:

- CPU Utilization
- Memory Utilization
- Running Tasks

---

### 2. ALB Monitoring

```
EC2
→ Load Balancer
→ Monitoring
```

Monitor:

- Request Count
- Target Response Time
- Target 5XX Errors

---

### 3. CloudWatch Logs

```
CloudWatch
→ Log Groups
→ /ecs/backend
```

Monitor:

- Exceptions
- Stack Traces
- Database Errors
- HTTP 500 Errors

---

# Why Container Insights?

Enabled in the ECS Cluster:

```terraform
setting {
  name  = "containerInsights"
  value = "enabled"
}
```

AWS automatically creates the required CloudWatch Container Insights log groups and publishes:

- CPU
- Memory
- Network RX/TX
- Task Metrics

No additional Terraform resources are required.

---

# Smoke Test

Run:

```bash
./run-live.sh smoke
```

Purpose:

- Verify application health
- Validate complete quiz journey
- Ensure APIs are working
- Verify thresholds

Smoke Test Results:

- 10 VUs
- 10 Shared Iterations
- 110/110 Checks Passed
- HTTP Failures = 0%
- P95 Response Time = 428 ms

Result:

✅ Application Healthy

---

# Load Test

Run:

```bash
./run-live.sh load
```

Scenario:

- Ramp to 20 Users
- Hold
- Ramp to 50 Users
- Hold
- Ramp Down

Thresholds:

- HTTP Failure < 2%
- Overall P95 < 1.5 s
- Quiz Start P95 < 800 ms
- Quiz Submit P95 < 1.2 s
- Leaderboard P95 < 600 ms

---

# Load Test Results

Execution Summary:

- 50 Max VUs
- 4300 HTTP Requests
- 1075 Quiz Iterations
- HTTP Failures = 0%
- Checks Passed = 9675 / 9675

Performance:

- Average Response = 1.36 s
- P95 Response = 3.48 s
- Maximum Response = 4.52 s

Threshold Result:

❌ Response Time Thresholds Failed

---

# AWS Observations

## ECS

CPU:

- Increased from ~3% to ~100%
- Remained saturated during peak load

Memory:

- Stable around 19%
- No significant increase

Conclusion:

**CPU became the bottleneck.**

---

## ALB

Request Count:

- Increased significantly during load

Target Response Time:

- Increased from ~105 ms
- Reached ~2.8 seconds

Target 5XX:

- No Errors

Conclusion:

Application remained available but responded more slowly under load.

---

# Bottleneck Analysis

Observed:

- CPU = ~100%
- Memory = ~19%
- HTTP Failures = 0%
- No 5XX Errors

Conclusion:

The backend ECS task became **CPU-bound**, not memory-bound.

The application stayed functional but response times increased because the single ECS task had exhausted its available CPU.

---

# Key Learnings

- Always verify the application manually before executing performance tests.
- Run a smoke test before a load test.
- Keep ECS Metrics, ALB Metrics, and CloudWatch Logs open while testing.
- High CPU does not necessarily mean application failure.
- Response time increases when CPU becomes saturated.
- Memory usage should be analyzed independently from CPU.
- CloudWatch metrics have a slight delay; refresh periodically during testing.

---

# Future Improvements

- Increase ECS CPU allocation (256 → 512 or higher)
- Enable ECS Service Auto Scaling
- Compare performance before and after scaling
- Tune application code if CPU remains the bottleneck
- Create CloudWatch Dashboards and Alarms for production monitoring

---

# Backend vs Frontend Load Test Comparison

| Metric | Backend Load Test | Frontend Load Test | Observation |
|---------|------------------:|-------------------:|-------------|
| Test Duration | ~4.5 minutes | 2 minutes | Backend test simulated a heavier workload |
| Max Virtual Users (VUs) | 50 | 20 | Backend received higher concurrent traffic |
| HTTP Requests | 4300 | 3216 | Backend processed more requests |
| Quiz Iterations | 1075 | 1072 | Similar number of user journeys |
| HTTP Failures | 0% | 0% | No request failures in either test |
| Checks Passed | 9675 / 9675 | 3216 / 3216 | All validations passed |
| Average Response Time | **1.36 s** | **412 ms** | Frontend responded significantly faster |
| P95 Response Time | **3.48 s** ❌ | **785 ms** ✅ | Backend exceeded threshold, frontend remained within SLA |
| Maximum Response Time | 4.52 s | 2.09 s | Backend experienced much higher latency |
| ECS CPU Utilization | ~100% | ~39% | Backend became CPU-bound, frontend remained healthy |
| ECS Memory Utilization | ~19% | ~14% | Memory was not a bottleneck for either service |
| ALB Target Response Time | ~2.8 s | ~175 ms | Backend latency was reflected at the ALB |
| ALB 5XX Errors | 0 | 0 | No server-side failures |
| CloudWatch Exceptions | None | None | Application remained stable throughout testing |

---

# Analysis

### Backend Service

- CPU utilization reached nearly **100%**.
- Memory utilization remained almost constant (~19%).
- Response times increased significantly under load.
- No HTTP failures or 5XX errors occurred.
- **Conclusion:** Backend became **CPU-bound**. The application stayed stable but responded more slowly due to CPU saturation.

---

### Frontend Service

- CPU utilization peaked at approximately **39%**.
- Memory utilization remained low (~14%).
- Response times stayed well below the configured threshold.
- No HTTP failures or 5XX errors occurred.
- **Conclusion:** Frontend handled the workload comfortably and did not become a bottleneck.

---

# Overall Conclusion

The performance bottleneck is **not the Application Load Balancer or the Frontend ECS Service**.

The **Backend ECS Service** is the primary bottleneck because it exhausted its available CPU resources while memory remained stable.

This indicates that the next optimization should focus on the backend by:

- Increasing ECS task CPU allocation.
- Enabling ECS Service Auto Scaling.
- Optimizing CPU-intensive application logic if required.

The frontend has sufficient capacity and does not require optimization at the current workload.

