
resource "aws_kms_key" "rds_kms" {
  count                   = var.environment == "prod" ? 1 : 0
  description             = "KMS key for RDS cluster encryption"
  deletion_window_in_days = 7
}


# Generate random password for RDS

resource "random_password" "rds_password" {
  length  = 16
  special = false
  # override_special = "asdfgjhkqwrtopASHLSGSAGNAX12345667890"
}

# RDS Subnet group for RDS instance
resource "aws_db_subnet_group" "dojo_rds_subnet_group" {
  name        = "${var.prefix}-${var.environment}-rds-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = module.network.rds_subnet_ids
  tags = {
    Name = "${var.prefix}-${var.environment}-rds-subnet-group"
  }
}

# RDS instance in private subnets
resource "aws_db_instance" "dojo_rds_instance" {
  count = var.environment != "prod" ? 1 : 0

  identifier              = "${var.prefix}-${var.environment}-rds-instance"
  engine                  = var.rds_instance_config.engine
  instance_class          = var.rds_instance_config.instance_class
  username                = var.rds_instance_config.username
  password                = random_password.rds_password.result
  db_name                 = var.db_name
  db_subnet_group_name    = aws_db_subnet_group.dojo_rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.dojo_rds_sg.id]
  publicly_accessible     = var.rds_instance_config.publicly_accessible
  backup_retention_period = var.rds_instance_config.backup_retention_period
  skip_final_snapshot     = var.rds_instance_config.skip_final_snapshot
  allocated_storage       = var.rds_instance_config.allocated_storage
  apply_immediately       = var.rds_instance_config.apply_immediately
  performance_insights_enabled = true

  tags = {
    Name = "${var.prefix}-${var.environment}-rds-instance"
  }
}

# RDS cluster for non-prod environments
resource "aws_rds_cluster" "dojo_rds_cluster" {
  count = var.environment == "prod" ? 1 : 0

  cluster_identifier      = "${var.prefix}-${var.environment}-rds-cluster"
  engine                  = var.aurora_cluster_config.engine
  engine_version          = var.aurora_cluster_config.engine_version
  master_username         = var.aurora_cluster_config.master_username
  master_password         = random_password.rds_password.result
  database_name           = var.db_name
  backup_retention_period = var.aurora_cluster_config.backup_retention_period
  preferred_backup_window = var.aurora_cluster_config.preferred_backup_window
  vpc_security_group_ids  = [aws_security_group.dojo_rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.dojo_rds_subnet_group.name
  storage_encrypted       = var.aurora_cluster_config.storage_encrypted
  kms_key_id              = aws_kms_key.rds_kms[0].arn

  tags = {
    environment = var.environment
    Name        = "${var.prefix}-${var.environment}-rds-cluster"
  }
}

# RDS writer for cluster
resource "aws_rds_cluster_instance" "dojo_writer" {
  count = var.environment == "prod" ? 1 : 0

  identifier         = "${var.prefix}-${var.environment}-rds-cluster-writer"
  cluster_identifier = aws_rds_cluster.dojo_rds_cluster[0].id
  # instance_class       = lookup(local.db_data, "instance_class", var.db_default_settings.instance_class)
  instance_class       = var.aurora_instance_config.instance_class
  engine               = aws_rds_cluster.dojo_rds_cluster[0].engine
  engine_version       = aws_rds_cluster.dojo_rds_cluster[0].engine_version
  publicly_accessible  = var.aurora_instance_config.publicly_accessible
  db_subnet_group_name = aws_security_group.dojo_rds_sg.id
  ca_cert_identifier   = var.aurora_instance_config.ca_cert_identifier
  apply_immediately    = var.aurora_instance_config.apply_immediately

  tags = {
    environment = var.environment
  }
}

resource "aws_rds_cluster_instance" "dojo_reader" {
  count              = var.environment == "prod" ? 1 : 0
  identifier         = "${var.prefix}-${var.environment}-rds-cluster-reader"
  cluster_identifier = aws_rds_cluster.dojo_rds_cluster[0].id
  # instance_class       = lookup(local.db_data, "instance_class", var.db_default_settings.instance_class)
  instance_class       = var.aurora_instance_config.instance_class
  engine               = aws_rds_cluster.dojo_rds_cluster[0].engine
  engine_version       = aws_rds_cluster.dojo_rds_cluster[0].engine_version
  publicly_accessible  = var.aurora_instance_config.publicly_accessible
  db_subnet_group_name = aws_security_group.dojo_rds_sg.id
  ca_cert_identifier   = var.aurora_instance_config.ca_cert_identifier
  apply_immediately    = var.aurora_instance_config.apply_immediately

  tags = {
    environment = var.environment
  }
}

# AWS secret manager for RDS credentials
resource "aws_secretsmanager_secret" "dojo_rds_secret" {
  name                    = "${var.prefix}-${var.environment}-rds-secrets"
  description             = "Secret for RDS credentials"
  recovery_window_in_days = 0
  tags = {
    Name = "${var.prefix}-${var.environment}-rds-secrets"
  }
}

# AWS secret manager secret version to store RDS credentials
resource "aws_secretsmanager_secret_version" "dojo_rds_secret_version" {
  secret_id = aws_secretsmanager_secret.dojo_rds_secret.id
  # db_link = "postgresql://{user}:{password}@{host}:{port}/{database_name}"
  secret_string = local.rds_connection_string
}
