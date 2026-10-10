# Creates an ECR repository for each ShopSphere application component.
resource "aws_ecr_repository" "this" {
  for_each             = toset(local.ecr_repos)
  name                 = each.value
  image_tag_mutability = "IMMUTABLE" # means same image tag cannot be overwritten with a new image
  force_delete         = true

  # Scans every image automatically after it is pushed inside repos.
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Automatically removes old images to control ECR storage usage.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"

      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }

      action = {
        type = "expire"
      }
    }]
  })
}