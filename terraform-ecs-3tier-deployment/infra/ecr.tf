resource "aws_ecr_repository" "ecr_repositories" {
  for_each             = local.service_names
  name                 = "${var.project}-${var.environment}-${each.key}"
  image_tag_mutability = "MUTABLE"
}


# output "ecr_repository_url_backend" {
#     value = aws_ecr_repository.ecr_repositories["backend"].repository_url
# }
# output "ecr_repository_url_frontend" {
#     value = aws_ecr_repository.ecr_repositories["frontend"].repository_url
# }

output "ecr_repository_urls" {
  value = {
    for service, repo in aws_ecr_repository.ecr_repositories : service => repo.repository_url
  }
}


#Explanation: Usually when ecr repository creates two repos one for frontend and another for backend. So to retreive the o/p we can run a loop and fetch the frontend and backend urls as per above logic. 

# When terraform creates the repo output looks like 
# {
#   backend  = "123456789.dkr.ecr.us-east-1.amazonaws.com/DevopsDojo-dev-backend"
#   frontend = "123456789.dkr.ecr.us-east-1.amazonaws.com/DevopsDojo-dev-frontend"
# }

# So in loop we are saying service = backend or frontend and repo is repo url. 
