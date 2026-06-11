# # Create ECR repository to store the application Docker Image. 
# resource "aws_ecr_repository" "sp_ecr_repo" {
#     name = "sp-ecr-repo"
#     image_tag_mutability = "IMMUTABLE"
# }


# output "ecr_repository_url" {
#     value = aws_ecr_repository.sp_ecr_repo.repository_url
# }