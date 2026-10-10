
# Configures the AWS provider.
provider "aws" {
  region = var.region
}

# Configures the Kubernetes provider to connect to the existing EKS cluster.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
