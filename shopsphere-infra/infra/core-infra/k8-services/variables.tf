variable "region" {
  default = "us-east-1"
}

# Which environment this Terraform apply targets.
variable "env" {
  description = "Environment key for this ShopSphere deployment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }

  validation {
    condition     = contains(keys(var.environments), var.env)
    error_message = "env must be a key in var.environments."
  }
}

# Environment-specific ShopSphere configuration.
variable "environments" {
  description = "ShopSphere environment configuration."

  type = map(object({
    environment_label = optional(string)
  }))

  default = {
    dev = {
      environment_label = "development"
    }

    prod = {
      environment_label = "production"
    }
  }
}

variable "project" {
  description = "Project name"
  type        = string
}

# Identifies the existing EKS cluster that hosts platform controllers.
variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster."
  type        = string
}