terraform {
  required_version = ">=1.1" # It's a major version where an be used more 1.1

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Minor version  can be used within 6xx version only
    }

    # Random plugin to generate random password for DB
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
