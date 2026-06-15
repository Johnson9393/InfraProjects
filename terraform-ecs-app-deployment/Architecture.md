# Student Portal Application Architecture

## Overview

The Student Portal application is deployed on AWS using a secure and scalable containerized architecture. The application runs on Amazon ECS Fargate, uses an Application Load Balancer (ALB) for traffic distribution, and stores data in Amazon RDS PostgreSQL.

The architecture follows a three-tier design:

1. Presentation Layer – Application Load Balancer (ALB)
2. Application Layer – ECS Fargate Tasks
3. Data Layer – Amazon RDS PostgreSQL

---

## High-Level Architecture

```text
Internet
    |
 HTTPS (443)
    |
+----------------------+
| Application Load     |
| Balancer (Public)    |
+----------------------+
    |
 HTTP (8000)
    |
+----------------------+
| ECS Fargate Tasks    |
| Spring Boot App      |
+----------------------+
    |
 PostgreSQL (5432)
    |
+----------------------+
| Amazon RDS           |
| PostgreSQL           |
+----------------------+
```

---

## Network Design

### Public Subnets

* Application Load Balancer (ALB) is deployed in public subnets.
* ALB receives internet traffic on ports 80 and 443.

### Private Subnets

* ECS Fargate tasks are deployed in private subnets.
* RDS PostgreSQL is deployed in private subnets.
* ECS tasks are not directly accessible from the internet.

---

## Request Flow

### HTTPS Request

1. User accesses the application using:

```text
https://student-portal-domain
```

2. Request reaches the Application Load Balancer.

3. ALB terminates SSL/TLS using the ACM certificate.

4. ALB forwards the request to healthy ECS tasks through the Target Group.

5. Spring Boot application processes the request.

6. If database access is required, ECS connects to PostgreSQL RDS.

7. Response is returned back to the user through the ALB.

---

## HTTP to HTTPS Redirection

The ALB listens on:

* Port 80 (HTTP)
* Port 443 (HTTPS)

Any request received on port 80 is automatically redirected to HTTPS using a 301 redirect.

```text
http://domain.com
        |
        v
301 Redirect
        |
        v
https://domain.com
```

This ensures all user traffic is encrypted.

---

## Target Group and Health Checks

The ALB uses a Target Group to manage ECS tasks.

Health Check Configuration:

* Path: `/login`
* Protocol: HTTP
* Expected Response: `200 OK`
* Interval: 30 seconds
* Timeout: 5 seconds
* Healthy Threshold: 2
* Unhealthy Threshold: 2

### How It Works

Every 30 seconds, the ALB sends:

```http
GET /login
```

to each ECS task.

If a task responds with:

```http
200 OK
```

it is considered healthy.

If a task fails health checks twice consecutively, it is marked unhealthy and removed from load balancing until it becomes healthy again.

---

## Security Architecture

### ALB Security Group

Allowed Inbound:

* TCP 80 from 0.0.0.0/0
* TCP 443 from 0.0.0.0/0

Purpose:

* Allows users from the internet to access the application.

---

### ECS Security Group

Allowed Inbound:

* TCP 8000 only from the ALB Security Group

Purpose:

* Prevents direct internet access to application containers.
* Only the ALB can communicate with ECS tasks.

---

### RDS Security Group

Allowed Inbound:

* TCP 5432 only from the ECS Security Group

Purpose:

* Only ECS tasks can access the database.
* Database is completely isolated from the internet.

---

## Why ALB to ECS Uses HTTP

User traffic is encrypted using HTTPS until it reaches the ALB.

```text
User --> HTTPS --> ALB
```

The ALB then forwards traffic internally to ECS using HTTP.

```text
ALB --> HTTP --> ECS
```

This approach is commonly used because:

* Traffic remains inside the AWS VPC.
* ECS tasks are not publicly accessible.
* Security Groups restrict access to ECS.
* Certificate management is simplified.
* TLS termination is handled by the ALB.

---

## Scalability

The architecture supports horizontal scaling through ECS Service Auto Scaling.

When traffic increases:

1. Additional ECS tasks are launched.
2. New tasks are automatically registered with the Target Group.
3. ALB begins routing traffic to the new healthy tasks.

When traffic decreases:

1. Excess tasks are terminated.
2. ALB stops sending traffic to removed tasks.

---

## Key AWS Services Used

* Amazon VPC
* Application Load Balancer (ALB)
* Amazon ECS Fargate
* Amazon RDS PostgreSQL
* AWS Certificate Manager (ACM)
* Amazon CloudWatch
* Security Groups
* Target Groups
* IAM Roles

---

## Summary

The Student Portal application follows AWS security and scalability best practices by exposing only the Application Load Balancer to the internet while keeping ECS tasks and the PostgreSQL database private. HTTPS is enforced at the ALB, health checks ensure traffic is sent only to healthy containers, and Security Groups control communication between each layer of the application.
