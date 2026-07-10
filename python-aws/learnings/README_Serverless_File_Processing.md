# AWS Serverless File Processing Architecture Notes

## Objective

Build a production-style, event-driven pipeline where uploaded files are
processed asynchronously instead of writing directly to the database.

## Recommended Architecture

``` text
User
   │
   ▼
ECS Backend
   │
Upload File
   ▼
S3 (incoming/)
   │
ObjectCreated Event
   ▼
Lambda
   │
Validate CSV
   │
Insert into RDS
   │
├── Success → archive/
└── Failure → error/
```

## Why S3 Instead of Writing Directly to RDS?

### Direct Backend → RDS

-   Backend remains busy until all records are inserted.
-   Large files can cause request timeouts.
-   Harder to recover from partial failures.
-   Original uploaded file may be lost.

### S3 → Lambda → RDS

-   Backend uploads file quickly and returns immediately.
-   Lambda processes the file asynchronously.
-   Original file is preserved in S3.
-   Failed files can be retried or moved to an `error/` folder.
-   Easy to archive files for audit/compliance.
-   Easier to extend the system with additional consumers.

## Important Note

Using Lambda **does not reduce the database workload**. Whether ECS or
Lambda inserts 100,000 rows, RDS still processes 100,000 inserts. The
main benefits are decoupling, resiliency, retries, and scalability.

## Production Best Practices

-   Store uploaded files in `incoming/`.
-   Move successful files to `archive/`.
-   Move failed files to `error/`.
-   Use AWS Secrets Manager for DB credentials.
-   Keep Lambda in a private subnet.
-   Allow Lambda → RDS using Security Groups.
-   Use an S3 Gateway VPC Endpoint for private S3 access.
-   Store shared libraries in Lambda Layers.
-   Enable CloudWatch Logs and Alarms.
-   Provision infrastructure using Terraform.
-   Deploy using GitHub Actions.

## Lambda Networking

Lambda (Private Subnet) │ ├── Security Group → RDS (3306/5432) └── S3
Gateway VPC Endpoint → S3

## Why Lambda Layers?

-   Keep Lambda code lightweight.
-   Reuse dependencies across functions.
-   Easier dependency management.
-   Better maintainability.

## Interview Summary

"I built an event-driven serverless pipeline where the application
uploads files to Amazon S3. An S3 ObjectCreated event triggers a Lambda
function, which validates the CSV, inserts records into Amazon RDS, logs
processing to CloudWatch, and moves files to archive or error folders.
The infrastructure is provisioned with Terraform and deployed using
GitHub Actions."

## Future Enhancement

For very large files:

``` text
S3
 │
 ▼
Lambda
 │
 ▼
SQS
 │
 ▼
Multiple Lambda Workers
 │
 ▼
Batch Inserts into RDS
```

This improves scalability and throughput.
