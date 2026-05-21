# Reflection Questions & Answers

## 1. Why did we create the NAT gateway before the ECS service? What error do you see if you flip the order?

We created the NAT gateway before the ECS service because ECS tasks running in private subnets need outbound internet access to:

* Pull Docker images from ECR
* Fetch secrets from Secrets Manager
* Send logs to CloudWatch

Without a NAT gateway, private ECS tasks cannot access the internet.

If we create ECS first without NAT, tasks fail during startup with errors like:

```text
CannotPullContainerError
```

or

```text
ResourceInitializationError
```

---

## 2. Why does the target group use IP target type instead of Instance?

ECS Fargate does not use EC2 instances directly.

Each Fargate task gets:

* Its own ENI (Elastic Network Interface)
* Its own private IP address

Therefore, the ALB must route traffic directly to task IPs.

That is why the target group type must be:

```text
IP
```

instead of:

```text
Instance
```

---

## 3. Why is the health check path `/login` and not `/`? What HTTP status code does `/` return for this app?

The `/` endpoint redirects users to `/login`.

So `/` returns:

```text
302 Redirect
```

But ALB health checks expect:

```text
200 OK
```

The `/login` endpoint directly returns:

```text
200 OK
```

Therefore `/login` is used for health checks.

---

## 4. Why are ALB security group, ECS security group, and RDS security group three separate groups that reference each other, instead of one big security group with all the rules?

Separate security groups provide:

* Better security
* Isolation between layers
* Least privilege access
* Easier troubleshooting

Traffic flow becomes controlled:

* Internet → ALB only
* ALB → ECS only
* ECS → RDS only

This is a layered security architecture and is considered production best practice.

---

## 5. The task definition uses `ValueFrom` instead of `Value` for `DB_LINK`. What's the security benefit? What permission does the execution role need to make this work?

Using `ValueFrom` allows ECS to securely fetch secrets from AWS Secrets Manager instead of hardcoding credentials inside the task definition.

Security benefits:

* Passwords are not exposed in task definitions
* Secrets can be rotated
* Credentials are stored securely
* No hardcoded secrets in GitHub or code

Required IAM permission:

```text
secretsmanager:GetSecretValue
```

This permission is attached to the ECS Task Execution Role.

---

## 6. Why does scale-in cooldown (300s) need to be longer than scale-out cooldown (60s)?

Scale-out should happen quickly during traffic spikes to maintain application performance.

Scale-in should happen slowly to avoid:

* Task thrashing
* Frequent task creation/deletion
* Service instability

A longer scale-in cooldown ensures traffic has actually reduced before removing tasks.

---

## 7. If your NAT gateway crashes, do running ECS tasks keep serving traffic? Why or why not? What about new tasks trying to start?

Yes, already running ECS tasks continue serving traffic because:

* Containers are already running
* Images are already pulled
* Existing network connections continue working

However, new tasks will fail to start because they cannot:

* Pull images from ECR
* Fetch secrets
* Send logs

Over time the service becomes unhealthy because replacements and scaling operations fail.
