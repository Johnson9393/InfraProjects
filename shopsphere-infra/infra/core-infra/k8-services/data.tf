# Retrieves the existing EKS cluster created by core-infra/cluster.
data "aws_eks_cluster" "cluster" {
  name = "${var.env}-${var.eks_cluster_name}"
}

# Retrieves the VPC associated with the EKS cluster.
data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
}

# Retrieves temporary authentication information for the EKS cluster.
data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}

# Retrieves the AWS account identity used by this Terraform execution.
data "aws_caller_identity" "current" {}

# Retrieves the active AWS partition, such as aws.
data "aws_partition" "current" {}