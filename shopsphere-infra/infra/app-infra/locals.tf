# Environment-specific naming and configuration.
locals {
  env_prefix        = "${var.env}-"
  cluster_namespace = "shopsphere-${var.env}"
  cluster_name      = "${var.env}-shopsphere"
  env_dns_suffix    = "${var.env}.${var.domain_name}"
  platform_env      = var.platform_env
  cluster_env_cfg   = var.environments[var.env] #map-key lookup sytax not list []
  cluster_env_label = coalesce(
    try(local.cluster_env_cfg.environment_label, null),
    var.env
  )
  alb_group_name = var.alb_group_name

  # ECR repository names for all ShopSphere application components.
  ecr_repos = [
    for repo in [
      "shopsphere-product-service",
      "shopsphere-user-service",
      "shopsphere-cart-service",
      "shopsphere-order-service",
      "shopsphere-payment-service",
      "shopsphere-notification-service",
      "shopsphere-api-gateway",
      "shopsphere-frontend",
      "shopsphere-seed",
    ] : "${local.env_prefix}${repo}"
  ]

  # Maps each Kubernetes Secret consumed by ShopSphere to its secret properties.
  secret_mappings = {
    "product-db-credentials" = [
      { secretKey = "username", subpath = "product-db", property = "username" },
      { secretKey = "password", subpath = "product-db", property = "password" },
    ]

    "user-db-credentials" = [
      { secretKey = "username", subpath = "user-db", property = "username" },
      { secretKey = "password", subpath = "user-db", property = "password" },
    ]

    "order-db-credentials" = [
      { secretKey = "username", subpath = "order-db", property = "username" },
      { secretKey = "password", subpath = "order-db", property = "password" },
    ]

    "payment-db-credentials" = [
      { secretKey = "username", subpath = "payment-db", property = "username" },
      { secretKey = "password", subpath = "payment-db", property = "password" },
    ]

    "redis-credentials" = [
      { secretKey = "password", subpath = "redis", property = "password" },
    ]

    "rabbitmq-credentials" = [
      { secretKey = "username", subpath = "rabbitmq", property = "username" },
      { secretKey = "password", subpath = "rabbitmq", property = "password" },
    ]

    "user-service-credentials" = [
      { secretKey = "jwt-secret", subpath = "user-service", property = "jwt_secret" },
    ]

    "order-service-credentials" = [
      { secretKey = "jwt-secret", subpath = "order-service", property = "jwt_secret" },
    ]

    "payment-service-credentials" = [
      { secretKey = "jwt-secret", subpath = "payment-service", property = "jwt_secret" },
      { secretKey = "razorpay-key-id", subpath = "payment-service", property = "razorpay_key_id" },
      { secretKey = "razorpay-key-secret", subpath = "payment-service", property = "razorpay_key_secret" },
    ]

    "app-secrets" = [
      { secretKey = "RAZORPAY_WEBHOOK_SECRET", subpath = "app", property = "razorpay_webhook_secret" },
    ]

    "notification-service-credentials" = [
      { secretKey = "aws-access-key-id", subpath = "notification-service", property = "aws_access_key_id" },
      { secretKey = "aws-secret-access-key", subpath = "notification-service", property = "aws_secret_access_key" },
    ]
  }

  # Represents the currently selected environment and its Kubernetes namespace.
  secret_envs = {
    (var.env) = {
      namespace = local.cluster_namespace
    }
  }

  # Builds the actual values that will be stored inside each AWS Secrets Manager secret.
  secret_values = {
    "product-db-credentials" = {
      username = "product_user"
      password = random_password.db[var.env].result
    }

    "user-db-credentials" = {
      username = "user_user"
      password = random_password.db[var.env].result
    }

    "order-db-credentials" = {
      username = "order_user"
      password = random_password.db[var.env].result
    }

    "payment-db-credentials" = {
      username = "payment_user"
      password = random_password.db[var.env].result
    }

    "redis-credentials" = {
      password = random_password.redis[var.env].result
    }

    "rabbitmq-credentials" = {
      username = "rabbitmq_user"
      password = random_password.rabbitmq[var.env].result
    }

    "user-service-credentials" = {
      jwt_secret = random_password.jwt[var.env].result
    }

    "order-service-credentials" = {
      jwt_secret = random_password.jwt[var.env].result
    }

    "payment-service-credentials" = {
      jwt_secret          = random_password.jwt[var.env].result
      razorpay_key_id     = var.razorpay_key_id
      razorpay_key_secret = var.razorpay_key_secret
    }

    "app-secrets" = {
      razorpay_webhook_secret = var.razorpay_webhook_secret
    }

    "notification-service-credentials" = {
      aws_access_key_id     = var.aws_access_key_id
      aws_secret_access_key = var.aws_secret_access_key
    }
  }

  # Builds environment-aware targets for each Kubernetes Secret.
  external_secret_targets = merge([
    for env_key, env_cfg in local.secret_envs : {
      for secret_name, mappings in local.secret_mappings :
      "${env_key}-${secret_name}" => {
        env_key     = env_key
        namespace   = env_cfg.namespace
        secret_name = secret_name
        mappings    = mappings
      }
    }
  ]...)


  # ---------------------------------------------------------------------------
  # CloudNativePG configuration — Dev only
  # ---------------------------------------------------------------------------

  # CNPG manages PostgreSQL in Dev.
  # Prod will use RDS, which will be configured separately later.
  cnpg_enabled_for_env = (
    var.enable_cnpg && var.env == "dev"
  )

  # Prepare the CNPG cluster configuration for databases.tf.
  # Reuse the existing shopsphere namespace and the cluster definitions
  # provided through var.cnpg_clusters.
  cnpg_clusters_effective = local.cnpg_enabled_for_env ? {
    for cluster_name, config in var.cnpg_clusters :
    cluster_name => merge(config, {
      cluster_name = cluster_name
      namespace    = local.cluster_namespace
      environment  = var.env
    })
  } : {}


  #----------------------------------------------------------------------------
  #
  #ACM Route 53 Settings
  #
  #----------------------------------------------------------------------------
  acm_cert_arn = coalesce(
    var.acm_cert_arn,
    aws_acm_certificate_validation.env.certificate_arn
  )


  # ---------------------------------------------------------------------------
  # ALB Ingress configuration for ShopSphere services
  # ---------------------------------------------------------------------------

  ingress_services = var.enable_cluster_resources ? {
    for target in flatten([
      for env_key, env_cfg in {
        (var.env) = local.cluster_env_cfg
        } : [
        for svc_key, svc_cfg in coalesce(
          try(env_cfg.ingress_services, null),
          var.ingress_services
          ) : {
          key       = "${env_key}-${svc_key}"
          env_key   = env_key
          namespace = local.cluster_namespace
          environment_label = coalesce(
            try(env_cfg.environment_label, null),
            env_key
          )

          svc_key = svc_key

          host = coalesce(
            try(svc_cfg.host, null),
            "${coalesce(try(svc_cfg.host_prefix, null), svc_key)}.${env_key}.${var.domain_name}"
          )

          path             = try(svc_cfg.path, "/")
          path_type        = try(svc_cfg.path_type, "Prefix")
          service_name     = svc_cfg.service_name
          service_port     = svc_cfg.service_port
          healthcheck_path = try(svc_cfg.healthcheck_path, "/health")
        }
        if try(svc_cfg.enabled, true) && var.enable_ingress
      ]
    ]) : target.key => target
  } : {}

}



