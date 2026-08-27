# always use fixed terraform version to avoid compatibility issues with terraform providers

terraform {
    
  required_version = "= 1.15.1"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }

    random = {
        source = "hashicorp/random"
        version = "~> 3.0"
    }
  }
}

terraform {
    backend "s3" {
        bucket         = "sp-state-bucket"
        key            = "eks/app-infra/dev/terraform.tfstate"
        region         = "us-east-1"
        use_lockfile   = true
        encrypt        = true
    }
}