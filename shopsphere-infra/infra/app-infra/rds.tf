# One Aurora Postgres system for prod ShopSphere.
# This is the cluster only. Not the machines. Not the four app databases.
# Dev skips this because local.rds_enabled is false.

resource "aws_rds_cluster" "shopsphere" {
  count = local.rds_enabled ? 1 : 0

  cluster_identifier = "${var.env}-shopsphere"
  engine             = "aurora-postgresql"
  engine_version     = "15.10"

  # AWS must create one starter database. The app will not use this name.
  # We add products, users, orders, payments later.
  database_name   = "postgres"
  master_username = "shopsphere_admin"
  master_password = random_password.db[var.env].result

  db_subnet_group_name   = aws_db_subnet_group.shopsphere[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  storage_encrypted   = true
  skip_final_snapshot = true

  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}

# Two machines on the one prod cluster: one writer, one reader.
# Index 0 is first in line to be the writer. 1 is the reader.
# Dev skips this. QA later uses the same two, smaller class.

resource "aws_rds_cluster_instance" "shopsphere" {
  count = local.rds_enabled ? 2 : 0

  identifier         = "${var.env}-shopsphere-${count.index}"
  cluster_identifier = aws_rds_cluster.shopsphere[0].id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.shopsphere[0].engine
  engine_version     = aws_rds_cluster.shopsphere[0].engine_version

  publicly_accessible = false
  promotion_tier      = count.index == 0 ? 1 : 2

  tags = {
    Environment = var.env
    Application = "shopsphere"
    Role        = count.index == 0 ? "writer-preferred" : "reader"
  }
}