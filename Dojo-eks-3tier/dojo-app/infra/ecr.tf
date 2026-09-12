resource "aws_ecr_repository" "repos" {
  for_each = local.service_names

  name                 = "${var.project}-${var.env}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete = true #This will delete the repository even if it contains images. Use with caution.
}


output "ecr_repository_urls" {
  value = {
    for service, repo in aws_ecr_repository.repos : service => repo.repository_url
  }
}

#output will give the following output when terraform apply is run
# {
#   backend  = "123456789.dkr.ecr.us-east-1.amazonaws.com/dojo-dev-backend"
#   frontend = "123456789.dkr.ecr.us-east-1.amazonaws.com/dojo-dev-frontend"
# } 