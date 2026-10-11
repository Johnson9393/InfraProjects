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


# ============================================================================
# CloudNativePG - PostgreSQL Clusters
# ============================================================================

variable "enable_cnpg" {
  description = "Enable PostgreSQL clusters managed by CloudNativePG in Dev."
  type        = bool
  default     = true
}

variable "cnpg_clusters" {
  description = "PostgreSQL cluster configuration and bootstrap credentials."
  type = map(object({
    database    = string
    owner       = string
    secret_name = string
  }))

  default = {
    product-db = {
      database    = "products"
      owner       = "product_user"
      secret_name = "product-db-credentials"
    }

    user-db = {
      database    = "users"
      owner       = "user_user"
      secret_name = "user-db-credentials"
    }

    order-db = {
      database    = "orders"
      owner       = "order_user"
      secret_name = "order-db-credentials"
    }

    payment-db = {
      database    = "payments"
      owner       = "payment_user"
      secret_name = "payment-db-credentials"
    }
  }
}

variable "cnpg_instances" {
  description = "Number of PostgreSQL instances per CNPG cluster."
  type        = number
  default     = 1
}

variable "cnpg_image" {
  description = "PostgreSQL container image used by CNPG."
  type        = string
  default     = "ghcr.io/cloudnative-pg/postgresql:15.4"
}

variable "cnpg_storage" {
  description = "Persistent storage requested per PostgreSQL instance."
  type        = string
  default     = "1Gi"
}

variable "cnpg_storage_class" {
  description = "StorageClass used for PostgreSQL persistent volumes."
  type        = string
  default = "gp2"
}

variable "storage_class" {
  description = "StorageClass for CNPG PVCs and RabbitMQ volumeClaimTemplates"
  default     = "gp2"
}

variable "cnpg_postgresql" {
  description = "PostgreSQL configuration parameters for CNPG clusters."

  type = object({
    max_connections      = string
    shared_buffers       = string
    effective_cache_size = string
    work_mem             = string
    maintenance_work_mem = string
  })

  default = {
    max_connections      = "100"
    shared_buffers       = "128MB"
    effective_cache_size = "256MB"
    work_mem             = "4MB"
    maintenance_work_mem = "64MB"
  }
}

variable "cnpg_resources" {
  description = "CPU and memory requests and limits for CNPG PostgreSQL instances."

  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })

  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "cnpg_enable_pod_monitor" {
  description = "Enable PodMonitor creation for CNPG PostgreSQL clusters."
  type        = bool
  default     = false
}


#----------------------------------------------------------------------------
#
#Redis configuration for the cart service
#
#-----------------------------------------------------------------------------
variable "redis_enabled" {
  type    = bool
  default = true
}

variable "redis_image" {
  default = "redis:7-alpine"
}

variable "redis_max_memory" {
  default = "256mb"
}

variable "redis_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "250m", memory = "256Mi" }
  }
}

#----------------------------------------------------------------------------
#
#RabbitMQ configuration for the Notification service
#
#-----------------------------------------------------------------------------

variable "rabbitmq_enabled" {
  type    = bool
  default = true
}

variable "rabbitmq_image" {
  default = "rabbitmq:3.12-management-alpine"
}

variable "rabbitmq_storage" {
  default = "1Gi"
}

variable "rabbitmq_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}



