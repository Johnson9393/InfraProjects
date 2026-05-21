# Issues Faced During ECS Fargate Deployment & Fixes

## 1. SQLAlchemy URL Parsing Error

### Error

```text id="9r7jlwm"
sqlalchemy.exc.ArgumentError:
Could not parse SQLAlchemy URL from given URL string
```

### Cause

The database secret from AWS Secrets Manager was incorrectly injected into ECS.

Initially the ARN was passed incorrectly, causing ECS to inject either:

* the ARN itself
* or the full JSON object

instead of the actual PostgreSQL connection string.

### Fix

Used the correct ECS environment variable configuration:

| Key     | Value Type | Value                                |
| ------- | ---------- | ------------------------------------ |
| DB_LINK | ValueFrom  | arn:aws:secretsmanager:...:DB_LINK:: |

This correctly injected:

```text id="9d8x0e"
postgresql://username:password@rds-endpoint:5432/dbname
```

into the container.

---

## 2. ECS Tasks Failed to Start Initially

### Error

```text id="k5sjlwm"
CannotPullContainerError
```

or

```text id="ux4lc8"
ResourceInitializationError
```

### Cause

Private ECS tasks did not have outbound internet access.

The NAT Gateway was either:

* missing
* or route table was not configured correctly.

### Fix

Created:

* NAT Gateway in public subnet
* Route `0.0.0.0/0` from private app subnet route table to NAT Gateway

This allowed ECS tasks to:

* pull images from ECR
* fetch secrets
* send logs to CloudWatch

---

## 3. SSL / HTTPS “Connection Not Secure”

### Cause

The ACM certificate only covered:

```text id="jlwm9r"
infralabx.space
www.infralabx.space
```

But the application was accessed using:

```text id="3xzjlwm"
sp.infralabx.space
```

which was not included in the certificate.

### Fix

Created a wildcard ACM certificate:

```text id="jvjlwm"
*.infralabx.space
```

Attached the new certificate to the ALB HTTPS listener.

HTTPS started working correctly.

---

## 4. Database Tables Not Created

### Error

```text id="2mwjlwm"
psycopg2.errors.UndefinedTable:
relation "user" does not exist
```

### Cause

`db.create_all()` existed inside:

```python id="jlwm7s"
if __name__ == "__main__":
```

But ECS runs Flask using Gunicorn:

```bash id="jlwm5m"
gunicorn run:app
```

So the `__main__` block never executed.

### Fix

Added:

```python id="jlwm1r"
db.create_all()
```

inside:

```python id="jlwm8q"
with app.app_context():
```

within `create_app()`.

This ensured tables are created automatically during ECS startup.

---
