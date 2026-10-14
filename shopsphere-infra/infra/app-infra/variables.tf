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
  description = "Environment-specific ShopSphere configuration."

  type = map(object({
    environment_label  = optional(string)
    namespace          = optional(string)
    target_revision    = optional(string)
    destination_server = optional(string)
    subdomain          = optional(string)
    values_file        = optional(string)
    argocd_app_name    = optional(string)
    helm_release_name  = optional(string)
    seed_job_enabled   = optional(bool)
    service_replicas   = optional(number)

    ingress_services = optional(map(object({
      enabled          = optional(bool, true)
      host             = optional(string)
      host_prefix      = optional(string)
      path             = optional(string, "/")
      path_type        = optional(string, "Prefix")
      service_name     = string
      service_port     = number
      healthcheck_path = optional(string, "/health")
    })))
  }))

  default = {
    dev = {
      environment_label = "development"
      namespace         = "shopsphere"
      subdomain         = "shop"
      seed_job_enabled  = true
      service_replicas  = 1
    }

    prod = {
      environment_label = "production"
      namespace         = "shopsphere"
      subdomain         = "shop"
      seed_job_enabled  = true
      service_replicas  = 1
    }
  }
}


variable "enable_cluster_resources" {
  description = "Provision namespace, data stores, ingress, and DNS on the cluster in var.cluster_name"
  type        = bool
  default     = false
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


variable "domain_name" {
  description = "ShopSphere Route 53 hosted domain"
  type        = string
  default     = "infralabx.space"
}

variable "acm_cert_arn" {
  description = "Optional existing ACM certificate ARN override"
  type        = string
  default     = null
}


# ---------------------------------------------------------------------------
# Ingress and ALB configuration
# ---------------------------------------------------------------------------

variable "enable_ingress" {
  description = "Enable ALB ingress resources for ShopSphere services"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "IngressClass handled by AWS Load Balancer Controller"
  type        = string
  default     = "alb"
}

variable "alb_group_name" {
  description = "Shared ALB group name for ShopSphere ingress resources"
  type        = string
  default     = "shopsphere-shared-alb"
}

variable "ingress_services" {
  description = "ShopSphere Kubernetes services exposed through ALB"
  type = map(object({
    enabled          = optional(bool, true)
    host             = optional(string)
    host_prefix      = optional(string)
    path             = optional(string, "/")
    path_type        = optional(string, "Prefix")
    service_name     = string
    service_port     = number
    healthcheck_path = optional(string, "/health")
  }))

  default = {
    frontend = {
      host_prefix      = "shop"
      service_name     = "frontend"
      service_port     = 80
      path             = "/"
      healthcheck_path = "/"
    }

    api-gateway = {
      host_prefix      = "api"
      service_name     = "api-gateway"
      service_port     = 80
      path             = "/"
      healthcheck_path = "/health"
    }

    product-service = {
      enabled          = false
      host_prefix      = "product"
      service_name     = "product-service"
      service_port     = 8001
      path             = "/"
      healthcheck_path = "/health"
    }

    user-service = {
      enabled          = false
      host_prefix      = "users"
      service_name     = "user-service"
      service_port     = 8002
      path             = "/"
      healthcheck_path = "/health"
    }

    cart-service = {
      enabled          = false
      host_prefix      = "cart"
      service_name     = "cart-service"
      service_port     = 8003
      path             = "/"
      healthcheck_path = "/health"
    }

    order-service = {
      enabled          = false
      host_prefix      = "orders"
      service_name     = "order-service"
      service_port     = 8004
      path             = "/"
      healthcheck_path = "/health"
    }

    payment-service = {
      enabled          = false
      host_prefix      = "payments"
      service_name     = "payment-service"
      service_port     = 8005
      path             = "/"
      healthcheck_path = "/health"
    }

    notification-service = {
      enabled          = false
      host_prefix      = "notifications"
      service_name     = "notification-service"
      service_port     = 8006
      path             = "/"
      healthcheck_path = "/health"
    }
  }
}


# Platform environment — ArgoCD and shared platform services
variable "platform_env" {
  description = "Environment hosting shared platform services"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.platform_env)
    error_message = "platform_env must be dev or prod."
  }
}

# Default number of application replicas
variable "service_replicas" {
  description = "Default replica count for ShopSphere services"
  type        = number
  default     = 1
}

# Enable or disable the database seed job
variable "seed_job_enabled" {
  description = "Whether to run the application database seed job"
  type        = bool
  default     = true
}

# Application subdomain used for hostnames
variable "app_subdomain" {
  description = "Application subdomain under the main domain"
  type        = string
  default     = "shopsphere"
}

# Route 53 hosted zone ID used for ALB alias records
variable "aws_alb_zoneid" {
  description = "Route 53 hosted zone ID for the ALB alias target"
  type        = string
  default     = null
  nullable    = true
}




