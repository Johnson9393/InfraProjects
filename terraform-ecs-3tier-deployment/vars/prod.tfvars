aurora_cluster_config = {
  engine                  = "aurora-postgresql"
  engine_version          = "14.22"
  master_username         = "postgres"
  database_name           = "dojoAuroraDb"
  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"
  storage_encrypted       = true
}

aurora_instance_config = {
  instance_class      = "db.r5.large"
  ca_cert_identifier  = "rds-ca-rsa2048-g1"
  apply_immediately   = true
  publicly_accessible = false
}