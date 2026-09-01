# Kubernetes Application Verification & Troubleshooting

## Overview

At this stage, the complete application stack was deployed and verified inside the EKS cluster:

    Frontend Deployment
          ↓
    Frontend Service
          ↓
    Backend Service
          ↓
    Backend Deployment
          ↓
    RDS PostgreSQL

The application was first tested internally using Kubernetes networking and later accessed locally using `kubectl port-forward`.

## 1. Verify Pods

Check all application Pods:

    kubectl get pods -n dojo

Expected:

    Backend Pods    → 1/1 Running
    Frontend Pods   → 1/1 Running

`1/1 Running` means the container is running and has passed its readiness check.

## 2. Verify Kubernetes Services and Endpoints

Check the Services:

    kubectl get svc -n dojo

Backend:

    backend-service
    ClusterIP
    port: 8080
    targetPort: 8000

Frontend:

    frontend-service
    ClusterIP
    port: 80
    targetPort: 80

Check which Pods are behind the Services:

    kubectl get endpoints -n dojo

Example:

    backend-service    10.0.3.163:8000,10.0.4.6:8000
    frontend-service   10.0.3.181:80,10.0.4.46:80

The endpoints confirm that the Service selector successfully found the matching Pods.

Note: `kubectl get endpoints` is deprecated in newer Kubernetes versions; EndpointSlice is the newer API.

## 3. Backend Image Pull Troubleshooting

Initial backend Pods showed:

    ImagePullBackOff

Check the exact reason:

    kubectl describe pod <POD_NAME> -n dojo

The event showed:

    Failed to pull image
    pull access denied, repository does not exist or may require authorization

The problem was an incorrect ECR image URI.

Incorrect:

    023192525105.dkr.ecr.us-east-1.amazonaws.dojo-dev-backend:<tag>

Correct:

    023192525105.dkr.ecr.us-east-1.amazonaws.com/dojo-dev-backend:<tag>

After correcting the image URI:

    kubectl apply -f backend.yaml

The new Pods successfully pulled the ECR image.

## 4. Backend CrashLoopBackOff — Database Host

After the image was fixed, the backend entered:

    CrashLoopBackOff

Check application logs:

    kubectl logs <POD_NAME> -n dojo

Initial error:

    psycopg2.OperationalError:
    could not translate host name "db" to address:
    Name or service not known

The application was falling back to its default database URL containing:

    @db:5432

The Kubernetes Secret contained `DB_LINK`, but the application expected the environment variable `DATABASE_URL`.

Fix in `backend.yaml`:

    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: backend-secret
          key: DB_LINK

The important distinction is:

    Secret key       → DB_LINK
    Environment var  → DATABASE_URL
    Application      → reads DATABASE_URL

## 5. Backend CrashLoopBackOff — PostgreSQL Dialect

After fixing `DATABASE_URL`, the application reported:

    sqlalchemy.exc.NoSuchModuleError:
    Can't load plugin: sqlalchemy.dialects:postgres

The stored connection string started with:

    postgres://

SQLAlchemy required:

    postgresql://

The Terraform secret generation was changed from:

    postgres://${...}

to:

    postgresql://${...}

Then:

    terraform plan
    terraform apply

Terraform updated the Secrets Manager secret and Kubernetes Secret with the corrected connection string.

## 6. Restart Backend After Secret Changes

Because the backend consumes the Secret through environment variables, existing Pods keep their old environment values.

Restart the Deployment:

    kubectl rollout restart deployment backend-deployment -n dojo

Verify:

    kubectl get pods -n dojo

New Pods were created and became:

    1/1 Running

## 7. Verify Backend Environment

To see the environment actually received by the running container:

    kubectl exec -n dojo <BACKEND_POD> -- env

This confirmed values such as:

    DB_HOST=dojo-dev-rds....rds.amazonaws.com
    DB_PORT=5432
    DB_NAME=dojo_db
    DATABASE_URL=...
    DB_USERNAME=postgres
    SECRET_KEY=...

`env` is useful because it verifies what the running application container actually received, rather than only checking the ConfigMap/Secret objects.

## 8. Verify Backend Health

The backend listens on port `8000`.

The container did not contain `curl` or `wget`, so Python was used for the HTTP test:

    kubectl exec -n dojo <BACKEND_POD> -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read().decode())"

Successful response:

    {"database":"connected","status":"healthy"}

This confirmed:

    Backend Pod
        ↓
    Application :8000
        ↓
    /health
        ↓
    RDS PostgreSQL
        ↓
    Connected

Important: database connectivity being healthy does not mean application tables already exist. Migrations are a separate operation.

## 9. Frontend Deployment

Deploy:

    kubectl apply -f frontend.yaml

Verify:

    kubectl get pods -n dojo

The frontend Pods progressed through:

    ContainerCreating
        ↓
    Running
        ↓
    1/1 Running

The frontend application itself listens on port `80`.

The Deployment contained:

    containerPort: 3000

This is only a declaration/metadata value; it does not force the application to listen on port 3000.

The Service correctly uses:

    port: 80
    targetPort: 80

Therefore the actual traffic path is:

    frontend-service:80
        ↓
    Frontend Pod:80
        ↓
    Node/Express application:80

The `containerPort` should eventually be changed to `80` for accurate documentation, but it does not control Service routing.

## 10. Verify Frontend → Backend Communication

Test the backend Service from inside a frontend Pod:

    kubectl exec -n dojo <FRONTEND_POD> -- wget -qO- http://backend-service:8080/health

Successful response:

    {"database":"connected","status":"healthy"}

This proved:

    Frontend Pod
        ↓
    backend-service:8080
        ↓
    Backend Pod:8000
        ↓
    Backend /health
        ↓
    RDS
        ↓
    Connected

The Service uses:

    port: 8080
    targetPort: 8000

So the frontend does not need to know the backend Pod IP. It communicates using the stable Kubernetes Service DNS name:

    backend-service:8080

## 11. Run Database Migrations

The migration was implemented as a Kubernetes Job rather than a Deployment.

Important Job configuration:

    apiVersion: batch/v1
    kind: Job

The Job runs:

    ./migrate.sh

It uses the same database configuration and Secret as the backend.

Job-specific settings:

    backoffLimit: 3

This allows the Job to retry failed execution attempts.

    restartPolicy: Never

This prevents the individual Job Pod from being restarted repeatedly; the Job controller handles retry attempts.

No `replicas`, Service, readiness probe, or liveness probe is required because the migration Pod performs a one-time task and then exits.

Apply:

    kubectl apply -f migration.yaml

Verify:

    kubectl get pods -n dojo

Successful result:

    backend-migration-xxxxx    0/1    Completed

`Completed` means the migration process finished successfully and the Pod no longer needs to run.

## 12. Verify Migration and Seed Data

Check the migration logs:

    kubectl logs job/backend-migration -n dojo

Successful output included:

    Running upgrade ... Initial migration
    Running upgrade ... Add topics and questions tables
    Running upgrade ... Add quiz sessions and attempts for leaderboard
    Data seeded successfully!
    Database setup completed successfully!

This confirms both schema migrations and seed operations completed.

## 13. Verify Database Tables

Using the running backend Pod:

    kubectl exec -n dojo <BACKEND_POD> -- python -c "from sqlalchemy import inspect; from app import create_app, db; app=create_app(); ctx=app.app_context(); ctx.push(); print(inspect(db.engine).get_table_names())"

Verified tables:

    ['alembic_version',
     'wiki_pages',
     'topics',
     'questions',
     'quiz_sessions',
     'quiz_attempts']

This proves the migration created the application schema in RDS.

## 14. Verify Seed Data

Check the number of seeded topics:

    kubectl exec -n dojo <BACKEND_POD> -- python -c "from app import create_app, db; from app.models import Topic; app=create_app(); app.app_context().push(); print('Topics:', Topic.query.count())"

Result:

    Topics: 3

This confirms the seed data was actually inserted into the database.

## 15. Local Browser Testing with Port Forward

Both Services are `ClusterIP`, so they are internal to the cluster.

For temporary local browser access:

    kubectl port-forward -n dojo service/frontend-service 8080:80

Then open:

    http://localhost:8080

Traffic flows:

    Browser
        ↓
    localhost:8080
        ↓
    kubectl port-forward
        ↓
    frontend-service:80
        ↓
    Frontend Pod:80

Port forwarding is temporary. If the command stops, the tunnel disappears and must be started again.

The migration Job completing does not affect the port-forward.

## 16. Final Verified Application Flow

The complete working flow is now:

    Browser
        ↓
    localhost:8080
        ↓
    frontend-service:80
        ↓
    Frontend Pods:80
        ↓
    backend-service:8080
        ↓
    Backend Pods:8000
        ↓
    RDS PostgreSQL
        ↓
    Migrated schema
        ↓
    Seeded application data

Verified successfully:

    ECR → Backend Pod                    ✅
    ECR → Frontend Pod                   ✅
    Backend → RDS                        ✅
    Frontend → Backend Service           ✅
    Backend health endpoint              ✅
    Database migrations                   ✅
    Database tables                       ✅
    Seed data                             ✅
    Frontend UI through port-forward      ✅

## 17. Practical Troubleshooting Order

When something fails, don't immediately change configuration. Check in this order:

    1. kubectl get pods -n dojo

       → Is the Pod Running/Ready?

    2. kubectl describe pod <POD_NAME> -n dojo

       → Check Kubernetes Events for scheduling,
         image, networking, or probe problems.

    3. kubectl logs <POD_NAME> -n dojo

       → Check application startup/runtime errors.

    4. kubectl exec -n dojo <POD_NAME> -- env

       → Verify the container received the expected configuration.

    5. kubectl get svc -n dojo

       → Verify Service ports and Service existence.

    6. kubectl get endpoints -n dojo

       → Verify Services have discovered matching Pods.

    7. Test from inside the cluster

       → Verify actual Service/application connectivity.

Common states:

    ImagePullBackOff
        → Image URI/tag or image-pull/authentication problem.

    CrashLoopBackOff
        → Container starts but repeatedly crashes.

    0/1 Running
        → Container is running but not Ready; investigate probes/application.

    1/1 Running
        → Container is running and passing readiness checks.

    Completed
        → One-time Job finished successfully.