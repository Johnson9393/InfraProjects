terraform {
  required_version = "1.12.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}


terraform {
    backend "s3" {
        bucket = "sp-terraform-state-bucket"
        key    = "terraform-ecs-app-deployment/infra/terraform.tfstate"
        region = "us-east-1"    
        use_lockfile = true
        encrypt = true
    }
}
