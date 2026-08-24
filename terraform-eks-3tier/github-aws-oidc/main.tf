locals {
  github_repo = [
    { user = "Johnson9393", repo = "InfraProjects", branch = "main" }
  ]


#Converted github_repo list into github_oidc_subjects list to be used in aws_iam_openid_connect_provider resource.
# format that aws oidc expects is repo:<user>/<repo>:ref:refs/heads/<branch> or repo:<user>/<repo>:* for all branches. Hence we are using a for loop to convert the list into the required format.
  github_oidc_subjects = distinct([
    for r in local.github_repo :
    r.branch == "*" ?
    "repo:${r.user}/${r.repo}:*" :
    "repo:${r.user}/${r.repo}:ref:refs/heads/${r.branch}"
  ])

}
