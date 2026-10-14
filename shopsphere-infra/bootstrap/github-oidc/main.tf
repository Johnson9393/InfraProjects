# Creates GitHub's OIDC Provider in AWS IAM.
# URL identifies GitHub as the trusted OIDC token issuer.
# client_id_list sets sts.amazonaws.com as the token audience, allowing AWS STS to use the token for role assumption.
resource "aws_iam_openid_connect_provider" "github_oidc_provider" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-aws-oidc"
  }
}