variable "project" {
    type = string
    description = "Devops Dojo project"
    default = "dojo"
}

variable "env" {
    type = string
    description = "Environment name"
    default = "dev"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "account_id" {
  type        = string
  description = "AWS Account ID"
  default     = "023192525105"
}

