# 2 private rds subnets
# Create subnet group for RDS
# Create RDS instance
# Random password for RDS
# secrete manager to store rds creds


# RDS Subnets
resource "aws_subnet" "rds_subnets" {
  count = length(var.rds_subnets)

  vpc_id            = data.aws_vpc.main.id
  cidr_block        = var.rds_subnets[count.index].cidr
  availability_zone = var.rds_subnets[count.index].availability_zone

  tags = {
    Name = "${var.project}-${var.env}-rds-subnet-${count.index + 1}"
  }
      
}


# RDS subnet group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project}-${var.env}-rds-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids = aws_subnet.rds_subnets[*].id

  tags = {
    Name = "${var.project}-${var.env}-rds-subnet-group"
  }
}

# Generate random password
resource "random_password" "rds_password" {
  length           = 10
  special          = false
  override_special = "abcdgktyhtfAZVNNHDD1223434"
}

# KMS key 

resource "aws_kms_key" "rds_kms" {
  description             = "KMS key for RDS and Secrets Manager"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.project}-${var.env}-rds-kms-key"
  }
}

resource "aws_kms_alias" "rds_kms_alias" {
  name          = "alias/${var.project}-${var.env}-rds-kms-key"
  target_key_id = aws_kms_key.rds_kms.id
}


# Create RDS instance
resource "aws_db_instance" "dojo_rds" {
    identifier              = "${var.project}-${var.env}-rds"
    db_name                 = "dojo_db"
    allocated_storage       = 30
    max_allocated_storage   =  50
    engine                  = "postgres"
    engine_version          = "17.5"
    instance_class          = "db.t3.medium"
    username                = "postgres"
    password                = random_password.rds_password.result
    port                    = 5432
    db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids  = [aws_security_group.dojo_rds_sg.id]
    skip_final_snapshot     = true
    publicly_accessible     = false
    ca_cert_identifier      = "rds-ca-rsa2048-g1"
    storage_encrypted       = true
    backup_retention_period = 7
    storage_type            = "gp3"
    kms_key_id              = aws_kms_key.rds_kms.id
    auto_minor_version_upgrade = true
    deletion_protection      = false
    copy_tags_to_snapshot     = true
    apply_immediately         = true

    tags = {
        Name = "${var.project}-${var.env}-rds"
    }
}

# Secrets Manager to store RDS credentials
resource "aws_secretsmanager_secret" "rds_secret" {
  name                      = "${var.project}-${var.env}-rds-secret"
  description               = "RDS credentials for ${var.project}-${var.env}-rds"
  recovery_window_in_days   = 7

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = "postgres://${aws_db_instance.dojo_rds.username}:${random_password.rds_password.result}@${aws_db_instance.dojo_rds.address}:${aws_db_instance.dojo_rds.port}/${aws_db_instance.dojo_rds.db_name}"

    lifecycle {
        create_before_destroy = true
    }
}

