provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "Test"
      project     = "student-portal"
      Terraform   = true
      repo        = "Infra"
    }
  }
}
