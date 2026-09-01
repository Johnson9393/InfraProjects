# Backend Deployment — Kubernetes Troubleshooting

## Overview

The backend application is deployed to the `dojo` namespace using a Kubernetes Deployment.

The Deployment:

- Runs 2 backend replicas.
- Pulls the backend image from Amazon ECR.
- Exposes container port `8000`.
- Loads non-sensitive configuration from `backend-config`.
- Loads sensitive values from `backend-secret`.
- Uses `/health` for readiness and liveness checks.
- Connects to PostgreSQL RDS.

## 1. Verify EKS Connection

Before deploying the application, verify the current Kubernetes context:

    kubectl config current-context

Expected:

    dojo-eks

Verify worker nodes:

    kubectl get nodes

Expected:

    STATUS
    Ready

## 2. Deploy Backend

The backend Deployment must contain the correct namespace:

    metadata:
      name: backend-deployment
      namespace: dojo

Apply:

    kubectl apply -f backend.yaml

Verify Pods:

    kubectl get pods -n dojo -l app=backend

The `-l app=backend` is a label selector. It returns only Pods having the label `app=backend`.

The label comes from:

    template:
      metadata:
        labels:
          app: backend

## 3. Issue — ImagePullBackOff

Initial Pod status:

    backend-deployment-856f5f97f-p9ntf   0/1   ImagePullBackOff

Check the reason:

    kubectl describe pod <POD_NAME> -n dojo

Important event:

    Failed to pull image
    ...
    pull access denied, repository does not exist or may require authorization

The actual problem was an incorrect ECR image URI.

Incorrect:

    023192525105.dkr.ecr.us-east-1.amazonaws.dojo-dev-backend:<tag>

Correct:

    023192525105.dkr.ecr.us-east-1.amazonaws.com/dojo-dev-backend:<tag>

Because the URI was malformed, Kubernetes interpreted the image as a Docker Hub image instead of an Amazon ECR image.

Fix the image in `backend.yaml`:

    image: 023192525105.dkr.ecr.us-east-1.amazonaws.com/dojo-dev-backend:<tag>

Then apply again:

    kubectl apply -f backend.yaml

## 4. Issue — CrashLoopBackOff

After fixing the ECR URI, the new Pod successfully pulled the image but repeatedly restarted:

    backend-deployment-...   0/1   CrashLoopBackOff

Check application logs:

    kubectl logs <POD_NAME> -n dojo

Initial database error:

    psycopg2.OperationalError:
    could not translate host name "db" to address:
    Name or service not known

The application was falling back to its default database connection string:

    postgresql://postgres:postgres@db:5432/devops_learning

The reason was a configuration-name mismatch.

`config.py` expects:

    DATABASE_URL

But the Kubernetes Deployment was injecting:

    DB_LINK

## 5. Fix — Map Kubernetes Secret Key to Application Variable

The Kubernetes Secret contains:

    DB_LINK

But the application expects:

    DATABASE_URL

These names do not have to be the same.

In `backend.yaml`, change:

    - name: DB_LINK
      valueFrom:
        secretKeyRef:
          name: backend-secret
          key: DB_LINK

to:

    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: backend-secret
          key: DB_LINK

Meaning:

    Kubernetes Secret key: DB_LINK
              ↓
    Container environment variable: DATABASE_URL
              ↓
    Python application reads: os.getenv("DATABASE_URL")

Apply:

    kubectl apply -f backend.yaml

## 6. Verify Environment Variables Inside the Pod

To see what the container actually received:

    kubectl exec -n dojo <POD_NAME> -- env

This showed values such as:

    DB_HOST=dojo-dev-rds....rds.amazonaws.com
    DB_PORT=5432
    DB_NAME=dojo_db
    DB_USERNAME=postgres
    DATABASE_URL=...
    SECRET_KEY=...

This confirmed that Kubernetes ConfigMaps and Secrets were being injected correctly.

`kubectl get configmap` shows the Kubernetes configuration object, while `env` inside the Pod shows what the running container actually received.

## 7. Issue — SQLAlchemy `postgres` Dialect Error

After fixing `DATABASE_URL`, the application produced:

    sqlalchemy.exc.NoSuchModuleError:
    Can't load plugin: sqlalchemy.dialects:postgres

The stored database connection string started with:

    postgres://

SQLAlchemy expected:

    postgresql://

The Terraform resource generating the secret contained:

    secret_string = "postgres://${aws_db_instance.dojo_rds.username}:..."

Fix:

    secret_string = "postgresql://${aws_db_instance.dojo_rds.username}:..."

This changed the generated database URL to the PostgreSQL dialect expected by SQLAlchemy.

## 8. Update the Existing Secret

Because the connection string was already stored in AWS Secrets Manager, changing Terraform code alone was not enough.

Run:

    terraform plan

Terraform detected:

    aws_secretsmanager_secret_version.rds_secret_version
    must be replaced

Apply:

    terraform apply

This updated:

    Terraform
      ↓
    AWS Secrets Manager
      ↓
    Kubernetes Secret
      ↓
    Backend Pod

## 9. ConfigMap Correction

The Terraform plan also detected an extra `}` in `ALLOWED_ORIGINS`:

    http://172.20.201.108:80}

It was corrected to:

    http://172.20.201.108:80

Terraform updated the Kubernetes ConfigMap accordingly.

## 10. Restart Pods After Secret/Config Changes

Because the backend consumes Secret/ConfigMap values through environment variables, existing Pods do not automatically receive the changed environment values.

Restart the Deployment:

    kubectl rollout restart deployment backend-deployment -n dojo

This creates new Pods using the updated configuration.

Verify:

    kubectl get pods -n dojo -l app=backend

Successful result:

    backend-deployment-...   1/1   Running
    backend-deployment-...   1/1   Running

## 11. Verify Backend Application Health

The backend listens on port `8000`.

The container image does not contain `curl` or `wget`, so Python was used for the HTTP test.

Check the application directly from inside the Pod:

    kubectl exec -n dojo <POD_NAME> -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read().decode())"

Successful response:

    {"database":"connected","status":"healthy"}

This confirms:

    Pod
      ↓
    Application
      ↓
    Port 8000
      ↓
    /health
      ↓
    PostgreSQL RDS
      ↓
    Connected

## 12. Important Health Check Understanding

The `/health` endpoint executes:

    SELECT 1

Therefore:

    Database connection = healthy

does not necessarily mean:

    Application schema/migrations = completed

RDS can be reachable even when application tables have not yet been created.

Database migrations are a separate step and will later create/update the application schema.

## 13. Useful Troubleshooting Commands

Check Deployment:

    kubectl get deployment backend-deployment -n dojo

Check Pods:

    kubectl get pods -n dojo -l app=backend

Check detailed Pod events:

    kubectl describe pod <POD_NAME> -n dojo

Check application logs:

    kubectl logs <POD_NAME> -n dojo

Check environment variables:

    kubectl exec -n dojo <POD_NAME> -- env

Check Service:

    kubectl get service backend-service -n dojo

Check application port from the Deployment:

    kubectl get deployment backend-deployment -n dojo -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}{"\n"}'

Test the application from inside the container:

    kubectl exec -n dojo <POD_NAME> -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read().decode())"

## 14. Troubleshooting Pattern

When a Pod is not working, follow this order:

    kubectl get pods -n dojo
        ↓
    kubectl describe pod <POD_NAME> -n dojo
        ↓
    Check Events
        ↓
    kubectl logs <POD_NAME> -n dojo
        ↓
    Check environment/configuration if required
        ↓
    Test application connectivity from inside the Pod

Common statuses:

    ImagePullBackOff
        → Image URI/tag or image-pull/authentication problem

    ErrImagePull
        → Kubernetes failed to pull the container image

    CrashLoopBackOff
        → Container starts but repeatedly exits/restarts

    0/1 Running
        → Container is running but not Ready; investigate probes/application

    1/1 Running
        → Container is running and passing its readiness check

## 15. Final Backend State

The backend is successfully running with:

    Deployment
        ↓
    2 Pods
        ↓
    ECR image
        ↓
    Container listening on port 8000
        ↓
    Kubernetes backend-service
        ↓
    RDS PostgreSQL

Verified response:

    {"database":"connected","status":"healthy"}

The next phase is the frontend Deployment, followed by testing frontend → backend Service communication and later implementing database migration execution.