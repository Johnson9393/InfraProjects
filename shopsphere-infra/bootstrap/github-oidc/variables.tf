
# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "ShopSphere project name"
  type        = string
  default     = "shopsphere"
}

variable "aws_region" {
  description = "AWS region used by ShopSphere"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  type        = string
  description = "AWS Account ID"
  default     = "023192525105"
}


# -----------------------------------------------------------------------------
# GitHub Repository Configuration
# export TF_VAR_github_owner="Johnson9393"
# export TF_VAR_github_repository="InfraProjects"
# we will export these variables in the shell before running terraform commands
# -----------------------------------------------------------------------------

variable "github_owner" {
  description = "GitHub repository owner or organization"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository containing ShopSphere"
  type        = string
}

variable "github_branch" {
  description = "Protected branch allowed to run trusted workflows"
  type        = string
  default     = "main"
}

variable "github_environments" {
  description = "GitHub Environments permitted for deployment"
  type        = set(string)
  default     = ["dev", "prod"]
}


variable "terraform_role_name_prefix" {
  description = "Prefix for environment-specific Terraform IAM roles"
  type        = string
  default     = "shopsphere-github-terraform"
}

variable "ecr_role_name_prefix" {
  description = "Prefix for environment-specific ECR push IAM roles"
  type        = string
  default     = "shopsphere-github-ecr"
}

