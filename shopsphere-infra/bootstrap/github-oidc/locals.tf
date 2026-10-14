# Convert github_repo into the GitHub OIDC subject format
# expected by the IAM role trust policy.
# Examples:
# repo:<user>/<repo>:ref:refs/heads/<branch>
# repo:<user>/<repo>:* for all branches
# format that aws oidc expects is repo:<user>/<repo>:ref:refs/heads/<branch> or repo:<user>/<repo>:* for all branches. Hence we are using a for loop to convert the list into the required format.

locals {
  # Branch-based GitHub OIDC subjects
  github_repo = [
    {
      user   = var.github_owner
      repo   = var.github_repository
      branch = var.github_branch
    }
  ]

  github_oidc_subjects = distinct([
    for r in local.github_repo :
    r.branch == "*" ?
    "repo:${r.user}/${r.repo}:*" :
    "repo:${r.user}/${r.repo}:ref:refs/heads/${r.branch}"
  ])

  # GitHub Environment-based OIDC subjects
  github_oidc_environment_subjects = [
    for env in var.github_environments :
    "repo:${var.github_owner}/${var.github_repository}:environment:${env}"
  ]

  # ECR repository ARN patterns for each configured environment
  ecr_repository_arn_patterns = [
    for env in var.github_environments :
    "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${env}-${var.project_name}-*"
  ]
}
