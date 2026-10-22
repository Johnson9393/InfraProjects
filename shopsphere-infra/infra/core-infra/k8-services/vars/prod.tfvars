# ============================================================================
# General
# ============================================================================

region           = "us-east-1"
project          = "shopsphere"
env              = "prod"
eks_cluster_name = "shopsphere"

# This apply is the prod cluster — install Argo, ACM, monitoring here too.
platform_env      = "prod"
enable_argocd     = true
enable_monitoring = true

# Own ALB group so prod ingresses do not share a name with dev.
alb_group_name = "shopsphere-prod-alb"