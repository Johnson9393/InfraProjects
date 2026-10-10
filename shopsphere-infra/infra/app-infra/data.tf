# Retrieves details of the existing ShopSphere EKS cluster.
data "aws_eks_cluster" "cluster" {
  name = "${var.env}-shopsphere"
}

# Retrieves an authentication token for the existing EKS cluster.
data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}