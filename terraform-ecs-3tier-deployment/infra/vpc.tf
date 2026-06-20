module "network" {
  source = "./modules/network"

  vpc_cidr        = var.vpc_cidr
  vpc_name        = "${var.environment}-${var.project}"
  aws_region      = var.aws_region
  need_ngw        = true
  need_single_ngw = true

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  rds_subnets     = var.rds_subnets

}