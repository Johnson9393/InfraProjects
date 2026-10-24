# Prod-only RDS network lookup.
# Dev skips this file. Prod uses the RDS subnets already created by
# shopsphere-infra/modules/vpc/vpc.tf from cluster/vars/prod.tfvars.
#
# data.aws_subnets filter "name" is an AWS filter key, not a label we invent:
#   vpc-id    = only subnets in the prod EKS VPC
#   tag:Name  = only subnets whose Name tag matches prod-shopsphere-vpc-rds-*
# Those names are prod-shopsphere-vpc-rds-1 and prod-shopsphere-vpc-rds-2.

locals {
  rds_enabled = var.env == "prod"
}

data "aws_subnets" "rds" {
  count = local.rds_enabled ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.cluster.vpc_config[0].vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-shopsphere-vpc-rds-*"]
  }
}

# RDS needs a named group of private subnets in two AZs.
# This is not a database. Clusters attach to this group later.
resource "aws_db_subnet_group" "shopsphere" {
  count = local.rds_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-db"
  description = "Private subnets for prod ShopSphere Postgres"
  subnet_ids  = data.aws_subnets.rds[0].ids

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}


# Firewall for the prod databases. Not a database.
# Ingress 5432 only from the prod EKS cluster security group.
# pods on those nodes can connect. Public internet cannot.
# count skips this on a dev apply.
resource "aws_security_group" "rds" {
  count = local.rds_enabled ? 1 : 0

  name        = "${var.env}-shopsphere-rds"
  description = "Postgres from the prod EKS cluster only"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id

  ingress {
    description     = "Postgres from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  tags = {
    Environment = var.env
    Application = "shopsphere"
  }
}