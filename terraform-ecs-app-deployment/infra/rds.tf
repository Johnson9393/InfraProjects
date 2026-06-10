# Generate random password for RDS

resource "random_password" "rds_password" {
  length           = 16
  special          = false
  override_special = "asdfgjhkqwrtopASHLSGSAGNAX12345667890"
}

# RDS Subnet group for RDS instance
resource "aws_db_subnet_group" "sp_rds_subnet_group" {
  name        = "sp-rds-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = [aws_subnet.sp_rds_subnet_1.id, aws_subnet.sp_rds_subnet_2.id]
  tags = {
    Name = "sp-rds-subnet-group"
  }
}

# RDS instance in private subnets
resource "aws_db_instance" "sp_rds_instance" {
    identifier             = "sp-rds-instance"
    engine                 = "postgres"
    instance_class         = "db.t3.micro"
    username               = "postgres"
    password               = random_password.rds_password.result
    db_name                = "sp-db"
    db_subnet_group_name   = aws_db_subnet_group.sp_rds_subnet_group.name
    vpc_security_group_ids = [aws_security_group.sp_rds_sg.id]
    publicly_accessible =  false
    backup_retention_period = 1
    skip_final_snapshot = true
    allocated_storage = 20
    apply_immediately = true
    
    tags = {
        Name = "sp-rds-instance"
    }
}

# AWS secret manager for RDS credentials
resource "aws_secretsmanager_secret" "sp_rds_secret" {
    name = "sp-rds-secret"
    description = "Secret for RDS credentials"
    tags = {
        Name = "sp-rds-secret"
    }
}

# AWS secret manager secret version to store RDS credentials
resource "aws_secretsmanager_secret_version" "sp_rds_secret_version" {
    secret_id     = aws_secretsmanager_secret.sp_rds_secret.id
    # db_link = "postgresql://{user}:{password}@{host}:{port}/{database_name}"
    secret_string = "postgresql://${aws_db_instance.sp_rds_instance.username}:${random_password.rds_password.result}@${aws_db_instance.sp_rds_instance.address}:${aws_db_instance.sp_rds_instance.port}/${aws_db_instance.sp_rds_instance.db_name}"
}
