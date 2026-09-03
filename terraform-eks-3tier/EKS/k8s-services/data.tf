data "aws_eks_cluster" "cluster" {
    name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
    name = var.cluster_name
}

data "aws_vpc" "main" {
    filter {
        name = "tag:Name"
        values = [var.vpc_name]
    }
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}