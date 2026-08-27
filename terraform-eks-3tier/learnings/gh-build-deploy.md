# GitHub Actions — EKS Build & Push to ECR

This workflow is the CI/build stage of the EKS 3-tier application. It detects application changes, builds the frontend and backend Docker images, authenticates to AWS using OIDC, pushes the images to ECR, and stores the Docker Buildx cache in ECR for faster future builds. The EKS deployment/CD stage comes next.

## Complete Workflow

    name: dojo-eks-build-deploy

    on:
      push:
        branches:
          - main
        paths:
          - "terraform-eks-3tier/dojo-app/src/**"

      workflow_dispatch:
        inputs:
          environment:
            type: choice
            description: "Select the environment to deploy to"
            required: true
            options:
              - dev
              - prod

    env:
      AWS_REGION: us-east-1
      AWS_ROLE_ARN: arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>

    jobs:
      build:
        runs-on: ubuntu-latest

        permissions:
          contents: read
          id-token: write

        strategy:
          matrix:
            services:
              - name: frontend
                path: terraform-eks-3tier/dojo-app/src/frontend
                ecr_repo: dojo-frontend

              - name: backend
                path: terraform-eks-3tier/dojo-app/src/backend
                ecr_repo: dojo-backend

        steps:

          - name: Checkout code
            uses: actions/checkout@v4

          - name: Set up Docker Buildx
            uses: docker/setup-buildx-action@v4

          - name: Configure AWS credentials
            uses: aws-actions/configure-aws-credentials@v4
            with:
              role-to-assume: ${{ env.AWS_ROLE_ARN }}
              aws-region: ${{ env.AWS_REGION }}

          - name: Login to ECR
            run: |
              ECR_REGISTRY=$(aws sts get-caller-identity \
                --query Account \
                --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

              aws ecr get-login-password \
                --region "${AWS_REGION}" | \
                docker login \
                --username AWS \
                --password-stdin "${ECR_REGISTRY}"

          - name: Build and Push ${{ matrix.services.name }}
            run: |
              ECR_REGISTRY=$(aws sts get-caller-identity \
                --query Account \
                --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

              docker buildx build \
                --platform linux/amd64 \
                --push \
                -t ${ECR_REGISTRY}/${{ matrix.services.ecr_repo }}:${{ github.sha }} \
                --cache-from type=registry,ref=${ECR_REGISTRY}/${{ matrix.services.ecr_repo }}:buildcache \
                --cache-to type=registry,ref=${ECR_REGISTRY}/${{ matrix.services.ecr_repo }}:buildcache,mode=max,image-manifest=true,oci-mediatypes=true \
                ${{ matrix.services.path }}

## What Each Part Means

`push` runs the workflow automatically when application code changes on `main`. `workflow_dispatch` allows a manual run and lets us select `dev` or `prod`. The environment value is not used by the build yet; it will be used later for deployment.

`AWS_REGION` defines the AWS region. `AWS_ROLE_ARN` identifies the IAM Role that GitHub will assume using OIDC.

`contents: read` allows GitHub to read the repository. `id-token: write` allows GitHub to request an OIDC token.

The matrix allows the same job to build both services:

    Frontend → frontend path → frontend ECR repository
    Backend  → backend path  → backend ECR repository

`actions/checkout` downloads the source code to the GitHub runner. Buildx provides the Docker BuildKit functionality needed for the AMD64 build and registry-based caching.

## AWS OIDC Authentication

The authentication flow is:

    GitHub Actions
          ↓
    OIDC Token
          ↓
    AWS OIDC Provider
          ↓
    IAM Trust Policy
          ↓
    Assume IAM Role
          ↓
    AWS STS
          ↓
    Temporary AWS Credentials

OIDC answers **"Who is GitHub?"**

The Trust Policy answers **"Is this GitHub repository/branch allowed to assume the role?"**

STS provides **temporary AWS credentials**.

IAM Permissions answer **"What can the role do?"**

No long-lived AWS access key or secret key is stored in GitHub.

For our ECR role, `ecr:GetAuthorizationToken` uses `Resource = "*"`. This is because getting the ECR authorization token is a registry-level operation. The actual image push permissions are restricted to the specific frontend and backend ECR repository ARNs.

The ECR repositories are created in a separate Terraform project/state. Therefore, the OIDC Terraform configuration uses ECR data sources to look up the existing repositories and get their ARNs instead of directly referencing resources from another Terraform state.

## ECR Login

The workflow gets the AWS Account ID dynamically:

    aws sts get-caller-identity --query Account --output text

`$(...)` means **execute the command and use its output**.

Then:

    aws ecr get-login-password

gets the ECR authorization token, and:

    docker login

uses that token to authenticate Docker with the ECR registry.

So the flow is:

    OIDC
      ↓
    Temporary AWS Credentials
      ↓
    ECR Authorization Token
      ↓
    Docker Login
      ↓
    ECR Access

## Docker Build and Push

The main command is:

    docker buildx build \
      --platform linux/amd64 \
      --push \
      -t ${ECR_REGISTRY}/${{ matrix.services.ecr_repo }}:${{ github.sha }} \
      --cache-from type=registry,ref=${ECR_REGISTRY}/${{ matrix.services.ecr_repo }}:buildcache \
      --cache-to type=registry,ref=${ECR_REGISTRY}/${{ matrix.services.ecr_repo }}:buildcache,mode=max,image-manifest=true,oci-mediatypes=true \
      ${{ matrix.services.path }}

`--platform linux/amd64` builds the image for AMD64.

`--push` pushes the image directly to ECR.

`-t` gives the image its ECR repository and tag.

`${{ github.sha }}` is the Git commit SHA, so every build gets a unique image version and we can identify exactly which commit created the image.

`${{ matrix.services.path }}` is the Docker build context and points Docker to the correct frontend or backend directory.

The image looks like:

    <ECR_REGISTRY>/<ECR_REPOSITORY>:<GIT_SHA>

Example:

    123456789012.dkr.ecr.us-east-1.amazonaws.com/dojo-frontend:a8c42f1

This gives us traceability from:

    Git Commit
        ↓
    Git SHA
        ↓
    Docker Image
        ↓
    ECR
        ↓
    Later → EKS

## Docker Build Cache

The cache is stored in ECR separately from the actual application image:

    ECR Repository
        │
        ├── <git-sha>
        │      → Actual Docker image
        │
        └── buildcache
               → Docker Buildx cache

`--cache-from` means:

    Read the existing buildcache from ECR
    and reuse unchanged Docker layers.

`--cache-to` means:

    Save the current build cache back to ECR
    so the next build can reuse it.

`mode=max` stores more build information so more layers can be reused.

`image-manifest=true` stores the cache using an image-manifest format.

`oci-mediatypes=true` uses OCI-standard media types for the cache.

The caching flow is:

    First Build
        ↓
    Build Image
        ↓
    Push Image
        ↓
    Save :buildcache

    Next Build
        ↓
    Read :buildcache
        ↓
    Reuse unchanged layers
        ↓
    Build changed layers
        ↓
    Create new complete image
        ↓
    Push new image with new Git SHA
        ↓
    Update :buildcache

The important point is that caching does **not** mean only changed files are pushed. Docker still creates a complete new image. Buildx simply avoids rebuilding layers that have not changed, making future builds faster.

## Complete Flow

    Git Push / Manual Run
            ↓
    Checkout Repository
            ↓
    Frontend / Backend Matrix
            ↓
    Docker Buildx
            ↓
    GitHub OIDC
            ↓
    AWS OIDC Provider
            ↓
    IAM Trust Policy
            ↓
    IAM Role
            ↓
    AWS STS Temporary Credentials
            ↓
    ECR Login
            ↓
    Read Existing Build Cache
            ↓
    Build Docker Image
            ↓
    Tag Image with Git SHA
            ↓
    Push Image to ECR
            ↓
    Save Updated Build Cache
            ↓
    Next: Deploy Image to EKS

## Final Mental Model

**GitHub builds the application → OIDC authenticates GitHub to AWS → Trust Policy controls who can assume the IAM Role → STS provides temporary credentials → IAM permissions control what the role can do → Docker logs into ECR → Buildx reuses the previous cache → Docker builds the image → Git SHA identifies the image → image is pushed to ECR → updated cache is saved → next stage deploys the image to EKS.**

This completes the **CI / Build / ECR Push** stage. The next phase is **CD / EKS Deployment**.