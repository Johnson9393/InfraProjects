environment = "dev"
db_name = "dojodb"
alarm_email = "johnson.johnny0903@gmail.com"

public_subnets = [
  {
    cidr              = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    prefix            = "public"
  },
  {
    cidr              = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    prefix            = "public"
  }
]

private_subnets = [
  {
    cidr              = "10.0.3.0/24"
    availability_zone = "us-east-1a"
    prefix            = "private"
  },
  {
    cidr              = "10.0.4.0/24"
    availability_zone = "us-east-1b"
    prefix            = "private"
  }
]

rds_subnets = [
  {
    cidr              = "10.0.5.0/24"
    availability_zone = "us-east-1a"
    prefix            = "rds"
  },
  {
    cidr              = "10.0.6.0/24"
    availability_zone = "us-east-1b"
    prefix            = "rds"
  }
]


frontend = {
  image_tag = "latest"
  port          = 80
  port_name     = "frontend"
  cpu           = 256
  memory        = 512
  need_alb      = true
  desired_count = 1
  environment = [
    {
      name  = "BACKEND_URL",
      value = "http://backend:8000"
    }
  ]
}

backend = {
  image_tag = "latest"
  port      = 8000
  port_name = "backend"
  cpu       = 256
  memory    = 512
  need_alb  = false
  desired_count = 1
}

rds_instance_config = {
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  username                = "postgres"
  db_name                 = "dojoDb"
  allocated_storage       = 20
  backup_retention_period = 1
  publicly_accessible     = false
  skip_final_snapshot     = true
  apply_immediately       = true
}


aurora_cluster_config = {
  engine = "aurora-postgresql"
  engine_version = "14.22"
  master_username  = "postgres"
  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"
  storage_encrypted = true
}

aurora_instance_config = {
  instance_class = "db.r5.large"
  ca_cert_identifier = "rds-ca-rsa2048-g1"
  apply_immediately = true
  publicly_accessible = false
}
