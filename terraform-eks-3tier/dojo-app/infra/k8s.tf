resource "kubernetes_namespace" "dojo" {
  metadata {
    labels = {
      name = var.project
    }

    name = var.project
  }
}

# backend Secrets
resource "kubernetes_secret" "backend_secret" {
  metadata {
    name      = "backend-secret"
    namespace = kubernetes_namespace.dojo.metadata[0].name
  }

  data = {
    DB_LINK     = aws_secretsmanager_secret_version.rds_secret_version.secret_string
    SECRET_KEY  = random_password.backend_secret_key.result
    DB_USERNAME = aws_db_instance.dojo_rds.username
    DB_PASSWORD = random_password.rds_password.result
  }

  type = "Opaque"
}

# Backend Config
resource "kubernetes_config_map" "backend_config" {
  metadata {
    name      = "backend-config"
    namespace = kubernetes_namespace.dojo.metadata[0].name
  }

  data = {
    DB_HOST         = aws_db_instance.dojo_rds.address
    DB_PORT         = aws_db_instance.dojo_rds.port
    DB_NAME         = aws_db_instance.dojo_rds.db_name
    ALLOWED_ORIGINS = "http://${kubernetes_service.frontend_service.spec[0].cluster_ip}:${kubernetes_service.frontend_service.spec[0].port[0].port}}"
  }
}


# frontend config

resource "kubernetes_config_map" "frontend_config" {
  metadata {
    name      = "frontend-config"
    namespace = kubernetes_namespace.dojo.metadata[0].name
  }

  data = {
    APP_VERSION = "1.0.0"
    APP_NAME    = "frontend"
    BACKEND_URL = "http://${kubernetes_service.backend_service.spec[0].cluster_ip}:${kubernetes_service.backend_service.spec[0].port[0].port}"

  }
}

# Serivices of backend and frontend

resource "kubernetes_service" "backend_service" {
  metadata {
    name      = "backend-service"
    namespace = kubernetes_namespace.dojo.metadata[0].name
  }

  spec {
    # The selector maps incoming traffic to pods matching this label
    selector = {
      app = "backend"
    }

    # Define how network traffic is routed
    port {
      port        = 8080  # Port exposed by the service
      target_port = 8000  # Port the container listens on inside the pod
      protocol    = "TCP" # Network protocol (TCP or UDP)
    }

    # Service types: ClusterIP, NodePort, LoadBalancer, or ExternalName
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "frontend_service" {
  metadata {
    name      = "frontend-service"
    namespace = kubernetes_namespace.dojo.metadata[0].name
  }

  spec {
    # The selector maps incoming traffic to pods matching this label
    selector = {
      app = "frontend"
    }

    # Define how network traffic is routed
    port {
      port        = 80    # Port exposed by the service
      target_port = 80    # Port the container listens on inside the pod
      protocol    = "TCP" # Network protocol (TCP or UDP)
    }

    # Service types: ClusterIP, NodePort, LoadBalancer, or ExternalName
    type = "ClusterIP"
  }
}


