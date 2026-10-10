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


# External Razorpay credentials supplied when deploying the environment.
variable "razorpay_key_id" {
  type      = string
  sensitive = true
}

variable "razorpay_key_secret" {
  type      = string
  sensitive = true
}

variable "razorpay_webhook_secret" {
  type      = string
  sensitive = true
}

# External AWS credentials used by the Notification Service.
variable "aws_access_key_id" {
  type      = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}


# Controls whether ESO resources are managed for this environment.
variable "enable_eso_secrets" {
  description = "Enable or disable ESO integration with AWS Secrets Manager."
  type        = bool
  default     = false
}
