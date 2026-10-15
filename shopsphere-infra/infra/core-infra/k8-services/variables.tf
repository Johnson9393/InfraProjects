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

variable "domain_name" {
  description = "ShopSphere Route 53 hosted domain"
  type        = string
  default     = "infralabx.space"
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

## for cnpg 
variable "cnpg_chart_version" {
  description = "CloudNativePG helm chart version"
  default     = "0.22.1"
}

variable "cnpg_namespace" {
  default = "cnpg-system"
}


# AWS Load Balancer Controller

variable "awsloadbalancercontroller_sa" {
  description = "Name of the AWS Load Balancer Controller service account"
  type        = string
  default     = "aws-load-balancer-controller"
}


# ---------------------------------------------------------------------------
# Platform services — ArgoCD
# ---------------------------------------------------------------------------

variable "platform_env" {
  description = "Environment where ArgoCD, Vault, and monitoring are deployed (shared by prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.platform_env)
    error_message = "platform_env must be dev or prod."
  }
}

variable "enable_argocd" {
  description = "Deploy ArgoCD on this cluster. Defaults to true only when env == platform_env (dev)."
  type        = bool
  default     = null
  nullable    = true
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
  default     = "7.7.16"
}

variable "alb_group_name" {
  description = "Shared ALB group name for ShopSphere ingress resources"
  type        = string
  default     = "shopsphere-shared-alb"
}

variable "app_subdomain" {
  description = "Application subdomain under the main domain"
  type        = string
  default     = "shopsphere"
}

variable "aws_alb_zoneid" {
  description = "Canonical hosted zone ID for ALBs in us-east-1"
  type        = string
  default     = "Z35SXDOTRQ7X7K"
}

# ---------------------------------------------------------------------------
# Monitoring stack — Prometheus, Grafana and Loki
# ---------------------------------------------------------------------------

variable "enable_monitoring" {
  description = "Deploy kube-prometheus-stack + Loki on this cluster. Defaults to true only when env == platform_env (dev)."
  type        = bool
  default     = null
  nullable    = true
}
