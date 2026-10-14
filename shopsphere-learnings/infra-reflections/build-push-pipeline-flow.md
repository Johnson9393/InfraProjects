# ShopSphere – Build and Push Docker Images to Amazon ECR

## 1. Overview

In our ShopSphere project, we use GitHub Actions to automatically build Docker images for our microservices and push them to Amazon Elastic Container Registry (ECR).

Our application contains multiple components, including the frontend, API Gateway, product service, user service, cart service, order service, payment service, notification service, and seed job.

Instead of building and pushing each image manually, we use a single reusable workflow with a matrix strategy to process multiple services.

**Our workflow follows this sequence:**

Code Push or Manual Trigger → Checkout Code → Configure Docker Buildx → Authenticate with AWS using OIDC → Log in to ECR → Build Docker Images → Push Images to ECR

The purpose of this workflow is to make our application images available in ECR so they can be deployed to our EKS cluster in a later phase.

## 2. Workflow Name and Triggers

```yaml
name: shopsphere-build-push

on:
  push:
    branches:
      - main
    paths:
      - "shopsphere-infra/app/**"

  workflow_dispatch:
    inputs:
      environment:
        type: choice
        description: "Select the environment"
        required: true
        options:
          - dev
          - prod
```

- **`name`** gives our workflow a readable name in GitHub Actions.
- **`push`** triggers the workflow when changes are pushed to the `main` branch.
- **`branches: main`** restricts the automatic trigger to pushes to `main`.
- **`paths`** means the workflow runs automatically only when files under the specified application directory change.
- **`workflow_dispatch`** allows us to trigger the workflow manually from GitHub Actions.
- **`inputs.environment`** lets us select either `dev` or `prod` when manually triggering the workflow.

We use this approach so application changes can trigger image builds automatically, while manual execution gives us control over which environment's ECR repositories receive the images.

The application path must match the actual directory structure in our GitHub repository.

## 3. Global Environment Variables

```yaml
env:
  AWS_REGION: us-east-1
  AWS_ROLE_ARN: arn:aws:iam::<AWS_ACCOUNT_ID>:role/github-ecr-role
```

- **`AWS_REGION`** specifies the AWS region where our ECR repositories are located.
- **`AWS_ROLE_ARN`** identifies the IAM role that GitHub Actions assumes to authenticate with AWS.

We use GitHub OIDC instead of storing long-lived AWS access keys in GitHub.

The AWS account ID in the role ARN must be replaced with the actual AWS account ID for our ShopSphere environment.

## 4. Job – Build and Push

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
```

Our workflow has a `build` job that runs on a GitHub-hosted Ubuntu runner.

The runner provides the environment in which GitHub Actions checks out our application code, authenticates with AWS, builds the Docker images, and pushes them to ECR.

## 5. Select the GitHub Environment

```yaml
environment:
  name: ${{ inputs.environment || 'dev' }}
```

This selects the GitHub Environment associated with the workflow run.

- If we manually trigger the workflow and select `prod`, it uses the `prod` environment.
- If we manually select `dev`, it uses `dev`.
- If the workflow is triggered automatically by a push, the input is not provided, so it defaults to `dev`.

This allows us to use one workflow for both environments instead of maintaining separate build workflows.

## 6. Workflow Permissions

```yaml
permissions:
  contents: read
  id-token: write
```

These permissions allow the workflow to read our repository and request an OIDC token from GitHub.

- **`contents: read`** allows GitHub Actions to check out and read the repository code.
- **`id-token: write`** allows GitHub Actions to request an OIDC token.

AWS STS validates the token against the IAM role's trust policy. If the workflow's identity is trusted, AWS issues temporary credentials for the role.

Those credentials allow the workflow to push Docker images to ECR according to the IAM role's permissions.

The `id-token: write` permission does not itself grant access to AWS resources. The IAM role determines what AWS operations are allowed.

## 7. Matrix Strategy

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - name: frontend
        context: shopsphere-infra/app/frontend
        ecr_suffix: frontend

      - name: api-gateway
        context: shopsphere-infra/app/api-gateway
        ecr_suffix: api-gateway

      - name: product-service
        context: shopsphere-infra/app/services/product-service
        ecr_suffix: product-service

      - name: user-service
        context: shopsphere-infra/app/services/user-service
        ecr_suffix: user-service

      - name: cart-service
        context: shopsphere-infra/app/services/cart-service
        ecr_suffix: cart-service

      - name: order-service
        context: shopsphere-infra/app/services/order-service
        ecr_suffix: order-service

      - name: payment-service
        context: shopsphere-infra/app/services/payment-service
        ecr_suffix: payment-service

      - name: notification-service
        context: shopsphere-infra/app/services/notification-service
        ecr_suffix: notification-service

      - name: seed-job
        context: shopsphere-infra/app/seed-job
        ecr_suffix: seed
```

The matrix lets us define multiple services in one workflow.

For every service, we specify three values:

- **`name`** identifies the service in the workflow logs.
- **`context`** identifies the directory containing the Docker build context, including the Dockerfile and required application files.
- **`ecr_suffix`** determines the service-specific suffix used to construct the ECR repository name.

GitHub Actions creates a separate matrix job for each listed service. Independent matrix jobs can run in parallel, subject to GitHub's runner and concurrency limits.

### What does `fail-fast: false` mean?

If one service build fails, GitHub Actions does not automatically cancel all the other matrix jobs because of that failure.

For example, if the payment-service image fails to build, the frontend and other service builds can continue.

This helps us identify failures across multiple services in the same workflow run.

## 8. Step 1 – Checkout Code

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

This checks out the repository onto the runner.

The runner needs the application source code, Dockerfiles, and other required build files before it can build the images.

The `actions/checkout` action is maintained by GitHub.

## 9. Step 2 – Set Up Docker Buildx

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
```

Docker Buildx provides advanced Docker build capabilities, including build caching and multi-platform image builds.

We use Buildx because our workflow needs to build multiple service images efficiently and reuse cached layers from previous builds.

We explicitly configure the target platform in the build command later.

## 10. Step 3 – Configure AWS Credentials

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ env.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

This step authenticates GitHub Actions with AWS using OIDC.

The action requests temporary AWS credentials by assuming our `github-ecr-role`.

The role's trust policy determines whether the workflow is allowed to assume the role, and its IAM permissions determine which ECR operations the workflow can perform.

We avoid storing permanent AWS access keys in the repository.

## 11. Step 4 – Log In to Amazon ECR

```bash
ECR_REGISTRY=$(aws sts get-caller-identity \
  --query Account \
  --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

aws ecr get-login-password --region "$AWS_REGION" |
  docker login \
    --username AWS \
    --password-stdin "$ECR_REGISTRY"
```

Before pushing an image, Docker needs to authenticate with ECR.

- **`aws sts get-caller-identity`** returns information about the AWS identity currently being used. We extract its account ID.
- **`ECR_REGISTRY`** constructs the ECR registry URL using the AWS account ID and region.
- **`aws ecr get-login-password`** retrieves an authentication token for ECR.
- **`docker login`** uses that token to authenticate Docker with the registry.

After this step succeeds, Docker can push images to repositories for which the assumed IAM role has permission.

The ECR registry URL follows this pattern:

`<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com`

## 12. Step 5 – Build and Push Docker Images

```bash
ECR_REGISTRY=$(aws sts get-caller-identity \
  --query Account \
  --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

ECR_REPOSITORY="${{ inputs.environment || 'dev' }}-shopsphere-${ECR_SUFFIX}"

docker buildx build \
  --platform linux/amd64 \
  --push \
  --tag "${ECR_REGISTRY}/${ECR_REPOSITORY}:${GITHUB_SHA}" \
  --cache-from "type=registry,ref=${ECR_REGISTRY}/${ECR_REPOSITORY}:buildcache" \
  --cache-to "type=registry,ref=${ECR_REGISTRY}/${ECR_REPOSITORY}:buildcache,mode=max,image-manifest=true,oci-mediatypes=true" \
  "$SERVICE_CONTEXT"
```

This is the main step where we build each Docker image and push it to ECR.

### Environment-specific repository name

```bash
ECR_REPOSITORY="${{ inputs.environment || 'dev' }}-shopsphere-${ECR_SUFFIX}"
```

This constructs the ECR repository name based on the selected environment and service.

For example:

- `dev-shopsphere-frontend`
- `dev-shopsphere-product-service`
- `prod-shopsphere-frontend`
- `prod-shopsphere-product-service`

The corresponding ECR repositories must already exist, and the IAM role must be allowed to push to them.

### Image platform

```bash
--platform linux/amd64
```

This tells Buildx to build an image for the Linux AMD64 platform. Our EKS worker nodes must be compatible with the image architecture.

### Image tag

```bash
--tag "${ECR_REGISTRY}/${ECR_REPOSITORY}:${GITHUB_SHA}"
```

We tag the image with the GitHub commit SHA.

The commit SHA identifies the source revision used to build the image. For example, the tag might look like:

`<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/dev-shopsphere-frontend:<COMMIT_SHA>`

This gives us an identifiable image for each source revision instead of relying only on a mutable tag such as `latest`.

### Push image

```bash
--push
```

This instructs Buildx to push the built image directly to ECR.

We do not need a separate `docker push` command because Buildx performs the push as part of the build operation.

### Build context

```bash
"$SERVICE_CONTEXT"
```

This tells Docker which directory to use as the build context for the current matrix service.

For example, the frontend build uses the frontend directory, while the product-service build uses the product-service directory.

## 13. Docker Build Cache

Our build command includes two cache options:

```bash
--cache-from "type=registry,ref=${ECR_REGISTRY}/${ECR_REPOSITORY}:buildcache"
--cache-to "type=registry,ref=${ECR_REGISTRY}/${ECR_REPOSITORY}:buildcache,mode=max,image-manifest=true,oci-mediatypes=true"
```

We store the Docker build cache in ECR so future builds can reuse previously built layers.

### `--cache-from`

This tells Buildx to retrieve an existing cache from the specified ECR cache reference.

If Dockerfile instructions and their inputs have not changed, Buildx may reuse cached layers instead of rebuilding them.

### `--cache-to`

This tells Buildx where to export the cache after building the image.

The cache is stored under the repository's `buildcache` reference, separate from the commit-SHA-tagged application image.

### `mode=max`

This exports cache information for intermediate as well as final build stages, which is useful when using multi-stage Dockerfiles.

### `image-manifest=true`

This configures the registry cache exporter to use an image manifest for the cache representation.

### `oci-mediatypes=true`

This uses OCI-standard media types for the exported cache representation.

These options help keep registry cache output compatible with the intended Buildx registry-cache configuration.

**Important:** The `buildcache` reference is used to speed up future builds. It is not the runnable application image that we deploy to EKS. Our application image uses the commit SHA tag.

## 14. Why Do We Use Docker Buildx Instead of Only Docker Build?

A normal Docker build can build an image, but Buildx provides additional capabilities we use in our pipeline, including registry-based caching and explicit platform selection.

Our goal is to reduce unnecessary build work, reuse cached layers, and push the resulting images to ECR as part of the same command.

The final image size still depends on how our Dockerfiles are designed. Multi-stage Dockerfiles and lean runtime images can help reduce that size.

## 15. End-to-End Workflow

Our Build and Push workflow works as follows:

1. A change is pushed to `main` under the configured application path, or we manually trigger the workflow.
2. We select `dev` or `prod` when triggering it manually.
3. GitHub Actions checks out the repository.
4. Docker Buildx is initialized.
5. GitHub Actions authenticates with AWS using OIDC and the ECR IAM role.
6. Docker logs in to the ECR registry.
7. The matrix strategy creates separate jobs for the listed application services.
8. Each job builds its service image using the correct build context.
9. The image is tagged with the selected environment's ECR repository name and the GitHub commit SHA.
10. Buildx retrieves reusable cache layers and exports the updated cache.
11. The built application image is pushed to ECR.

**Our key principle is Build → Tag → Push.** This workflow prepares version-identifiable container images in ECR for a later deployment workflow.

## 16. Important Notes

- The application paths in the workflow must match the actual GitHub repository directory structure.
- The AWS account ID and IAM role ARN must match our actual AWS setup.
- The ECR repositories must exist before the workflow attempts to push images.
- The ECR IAM role must have permission to authenticate with ECR and push to the intended repositories.
- The selected environment must correspond to the correct ECR repositories and AWS account.
- The commit SHA identifies the source revision used to build an image, but it does not guarantee that the build is secure or free from vulnerabilities.
- The registry cache is not the same as the application image.
- The matrix allows independent service builds to run in parallel, but available runner capacity can affect the total execution time.
- This workflow builds and pushes images. It does not deploy them to EKS or perform the Terraform infrastructure changes.
- We will implement deployment, image promotion, and additional DevSecOps security checks in later phases.

The overall goal is to build a repeatable pipeline that creates identifiable Docker images, pushes them to the correct ECR repositories, and uses caching to improve build efficiency.