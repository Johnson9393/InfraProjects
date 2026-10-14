# ShopSphere – Terraform Infrastructure Pipeline

## 1. Overview

In our ShopSphere project, we use GitHub Actions to automate Terraform infrastructure management on AWS.

The workflow allows us to select an environment (`dev` or `prod`) and a Terraform directory, validate our configuration, generate a Terraform plan, review the proposed changes, and apply them only after manual approval.

**Our workflow follows this sequence:**

Manual Trigger → Terraform Plan → Review Plan → Manual Approval → Terraform Apply

The important point is that **Terraform Apply must not execute until we have reviewed and approved the plan.**

## 2. Workflow Trigger – `workflow_dispatch`

We use `workflow_dispatch` because we want to trigger the infrastructure pipeline manually from GitHub Actions.

We provide two inputs:

- **Environment:** Select `dev` or `prod`.
- **Infrastructure path:** Select the Terraform directory we want to manage.

Our available Terraform directories are:

- `shopsphere-infra/infra/core-infra/cluster`
- `shopsphere-infra/infra/core-infra/k8-services`
- `shopsphere-infra/infra/app-infra`

This allows us to manage different infrastructure components independently without running Terraform against every directory.

## 3. Workflow Permissions

```yaml
permissions:
  contents: read
  id-token: write
```

- **`contents: read`** allows GitHub Actions to read our repository contents, mainly to check out the Terraform code.
- **`id-token: write`** allows GitHub Actions to request an OIDC token from GitHub.

AWS STS validates this token against the IAM role's trust policy. If the workflow is trusted, AWS issues temporary credentials for the role.

We use these credentials to authenticate with AWS without storing long-lived AWS access keys in GitHub.

The IAM role determines which AWS resources the workflow can access or modify.

## 4. Global Environment Variables

```yaml
env:
  AWS_REGION: us-east-1
  TF_VERSION: "1.15.5"
  TF_IN_AUTOMATION: "true"
  TF_INPUT: "false"
  TF_ENV: ${{ inputs.environment }}
```

- **`AWS_REGION`** specifies the AWS region used by the workflow.
- **`TF_VERSION`** specifies the Terraform version installed by GitHub Actions.
- **`TF_IN_AUTOMATION: "true"`** tells Terraform it is running inside an automated pipeline.
- **`TF_INPUT: "false"`** prevents Terraform from asking interactive questions.
- **`TF_ENV`** stores the environment selected when triggering the workflow, such as `dev` or `prod`.

These variables avoid repeating the same values throughout the workflow.

## 5. Job 1 – Terraform Plan

The first job is responsible for validating the Terraform configuration and preparing the infrastructure changes for review.

### Step 1: Checkout Code

```yaml
- uses: actions/checkout@v4
```

This downloads the repository code onto the GitHub Actions runner so Terraform can access our configuration files and modules.

### Step 2: Ensure the Workflow Runs from Main

```bash
if [[ "$GITHUB_REF" != "refs/heads/main" ]]; then
  echo "::error::Run this workflow from the main branch."
  exit 1
fi
```

This checks which branch triggered the workflow.

If the workflow is run from a branch other than `main`, the job fails before Terraform runs. This check enforces our intended branch restriction, although repository branch protection should also be configured separately.

### Step 3: Configure AWS Credentials

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ inputs.environment == 'dev' && vars.AWS_TERRAFORM_ROLE_ARN_DEV || vars.AWS_TERRAFORM_ROLE_ARN_PROD }}
    aws-region: ${{ env.AWS_REGION }}
```

This authenticates GitHub Actions with AWS using OIDC.

The selected environment determines which IAM role ARN is used:

- `dev` uses `AWS_TERRAFORM_ROLE_ARN_DEV`.
- `prod` uses `AWS_TERRAFORM_ROLE_ARN_PROD`.

We configure these as GitHub Actions repository variables containing the respective IAM role ARNs.

After successful authentication, subsequent steps can use the temporary AWS credentials according to the role's permissions.

### Step 4: Set Up Terraform

```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: ${{ env.TF_VERSION }}
```

This installs the Terraform version specified in our workflow, which is `1.15.5`.

Our Terraform configuration must allow this version. For example:

```hcl
terraform {
  required_version = ">= 1.12.0"
}
```

Terraform 1.15.5 satisfies this constraint because it is newer than 1.12.0.

### Step 5: Check Environment Configuration

```bash
test -s "vars/${TF_ENV}.tfbackend" || {
  echo "::error::Missing or empty backend configuration"
  exit 1
}

test -s "vars/${TF_ENV}.tfvars" || {
  echo "::error::Missing or empty variable file"
  exit 1
}
```

Before initializing Terraform, we check whether the selected environment's backend configuration and variable files exist and are not empty.

For example, selecting `dev` checks:

- `vars/dev.tfbackend`
- `vars/dev.tfvars`

If either file is missing or empty, the job fails instead of proceeding with incomplete configuration.

### Step 6: Terraform Format Check

```bash
terraform fmt -check -recursive
```

This checks whether Terraform files are formatted correctly throughout the selected directory and its subdirectories.

The `-recursive` option checks nested directories too.

Because we use `-check`, Terraform reports formatting problems without modifying the files.

### Step 7: Terraform Init

```bash
terraform init \
  -backend-config="vars/${TF_ENV}.tfbackend"
```

This initializes Terraform using the backend configuration for the selected environment.

Our backend configuration tells Terraform where to store and retrieve its state, such as our S3 state bucket and state-file key.

Terraform also downloads the required providers and initializes the modules.

We use separate backend configuration files to keep Dev and Prod state separate.

### Step 8: Terraform Validate

```bash
terraform validate
```

This checks whether our Terraform configuration is syntactically valid and internally consistent.

It helps identify configuration errors before generating the plan. It does not guarantee that every AWS operation will succeed.

### Step 9: Terraform Plan

```bash
terraform plan \
  -var-file="vars/${TF_ENV}.tfvars" \
  -out=tfplan

terraform show -no-color tfplan | tee tfplan.txt
```

This is the main step of the Plan job.

- **`terraform plan`** calculates the changes required to bring the actual infrastructure closer to our desired configuration.
- **`-var-file`** loads the variable values for the selected environment, such as `vars/dev.tfvars`.
- **`-out=tfplan`** saves the proposed changes in a Terraform plan file that can be applied later.
- **`terraform show -no-color tfplan`** converts the saved plan into readable text.
- **`tee tfplan.txt`** displays the readable plan in the GitHub Actions logs and saves the same output to `tfplan.txt`.

For example, if our Terraform configuration defines three subnets but only two currently exist, the plan may propose creating the missing subnet.

The Plan command does not create or modify those resources.

We can open the Terraform Plan step in GitHub Actions and review the proposed changes without downloading any files.

### Step 10: Upload Terraform Plan

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: terraform-plan-${{ inputs.environment }}-${{ github.run_id }}
    path: |
      ${{ inputs.infra_path }}/tfplan
      ${{ inputs.infra_path }}/tfplan.txt
    if-no-files-found: error
    retention-days: 5
```

This uploads both plan files to GitHub's artifact storage.

- **`name`** gives the artifact a unique name using the environment and GitHub's automatically generated workflow run ID.
- **`path`** specifies the saved plan and readable text file to upload.
- **`if-no-files-found: error`** fails the step if the expected files are missing.
- **`retention-days: 5`** tells GitHub to retain the artifact for five days.

The artifact is stored by GitHub, not inside the temporary runner. We need it because the Apply job runs on a separate runner and cannot automatically access files created by the Plan job.

The binary `tfplan` may contain sensitive values, so artifact access must be restricted appropriately.

## 6. Job 2 – Terraform Apply

The second job executes the saved Terraform plan, but only after the Plan job succeeds and the required approval is granted.

### Step 1: Wait for Terraform Plan

```yaml
needs: terraform-plan
```

This tells GitHub Actions that the Apply job depends on the successful completion of the Plan job.

If Plan fails, Apply does not proceed.

### Step 2: Configure the GitHub Environment

```yaml
environment:
  name: ${{ inputs.environment }}
```

This associates the Apply job with the selected GitHub Environment, either `dev` or `prod`.

We configure required reviewers under GitHub repository Settings → Environments.

Once the Plan job completes, the Apply job waits at the environment protection gate until an authorized reviewer approves it.

Adding the environment alone does not create an approval gate; required reviewers must be configured.

We use this approval mechanism for both Dev and Prod in our current design.

### Step 3: Checkout Code

```yaml
- uses: actions/checkout@v4
```

This checks out the repository again because the Apply job runs on its own runner.

Terraform needs the configuration files and modules when initializing and applying the saved plan.

### Step 4: Configure AWS Credentials

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ inputs.environment == 'dev' && vars.AWS_TERRAFORM_ROLE_ARN_DEV || vars.AWS_TERRAFORM_ROLE_ARN_PROD }}
    aws-region: ${{ env.AWS_REGION }}
```

This authenticates the Apply job with AWS using the selected environment's Terraform IAM role.

The role must have the permissions required to apply the proposed infrastructure changes.

### Step 5: Set Up Terraform

```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: ${{ env.TF_VERSION }}
```

This installs the same Terraform version used in the Plan job.

Keeping the Terraform version consistent helps ensure that the saved plan can be applied correctly.

### Step 6: Download Terraform Plan

```yaml
- uses: actions/download-artifact@v4
  with:
    name: terraform-plan-${{ inputs.environment }}-${{ github.run_id }}
    path: ${{ inputs.infra_path }}
```

This downloads the artifact created by the Plan job into the selected Terraform directory.

We use the same environment and run ID in the artifact name so the Apply job retrieves the plan associated with that workflow run.

### Step 7: Terraform Init

```bash
terraform init \
  -backend-config="vars/${TF_ENV}.tfbackend"
```

The Apply runner must initialize Terraform again because it is a separate runner.

This connects Terraform to the correct backend, downloads the required providers, and initializes the modules before applying the saved plan.

### Step 8: Terraform Apply

```bash
terraform apply tfplan
```

This executes the saved plan file produced by the Plan job.

Because we are passing a saved plan, Terraform does not ask for the usual interactive approval confirmation. The GitHub Environment approval is our manual approval gate.

We do not need `-auto-approve` for this saved-plan command.

After the approval gate is passed, the pipeline applies the proposed changes to AWS, provided the plan is still valid and the AWS permissions are sufficient.

If the plan is unexpected, we should not approve it. We should cancel the run, make the necessary Terraform changes, push the updated code, and trigger a fresh Plan for review.

## 7. End-to-End Workflow

Our complete infrastructure workflow works as follows:

1. Manually trigger the workflow from `main`.
2. Select the environment and Terraform directory.
3. GitHub Actions checks out the code and authenticates with AWS using OIDC.
4. Terraform checks the environment files, formatting, initialization, and configuration.
5. Terraform Plan calculates the proposed changes.
6. The plan is displayed in the logs and saved as `tfplan.txt`.
7. Both plan files are uploaded to GitHub artifact storage.
8. The Apply job waits for approval through the selected GitHub Environment.
9. We review the plan and approve or reject the Apply job.
10. After approval, the Apply job downloads the saved plan, initializes Terraform, and applies the plan to AWS.

**Our key principle is Plan → Review → Approve → Apply.** This gives us control over infrastructure changes instead of automatically applying every proposed change.

## 8. Important Notes

- The Terraform directory paths in the workflow must match the actual folder structure in the GitHub repository.
- The GitHub repository variables must contain the correct Dev and Prod IAM role ARNs.
- The AWS IAM trust policies must allow the intended GitHub repository, branch, and environment identities.
- Required reviewers must be configured for both GitHub Environments.
- Terraform state should be stored remotely and kept separate for Dev and Prod.
- Saved plan files and workflow artifacts must be protected because they can contain sensitive information.
- The current workflow manages one selected Terraform directory per run. Dependencies between infrastructure components must be considered when choosing the execution order.
- This is our production-style foundation. We can introduce additional hardening, least-privilege IAM, concurrency controls, and stronger deployment protections in a later phase.

