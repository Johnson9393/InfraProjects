
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  # Bootstrap configuration has its own remote state.
  backend "s3" {
    bucket       = "shopsphere-terraform-state009"
    key          = "bootstrap/github-oidc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
