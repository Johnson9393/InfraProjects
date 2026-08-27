#added public and private subnets tags in the network module so EKS/Kubernetes can automatically discover the correct subnets for creating AWS Load Balancers and other Kubernetes-managed networking resources.

# These tags are kubernets discovery tags, which are used by the AWS cloud provider in Kubernetes to identify which subnets should be used for creating load balancers and other networking resources.

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  

  enable_nat_gateway = true
  single_nat_gateway  = var.need_1_ngw
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    //"kubernetes.io/role/internal-elb" = 1
  }

}