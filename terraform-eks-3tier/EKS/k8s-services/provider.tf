# Kubernetes provider: allows Terraform to connect to and manage resources inside the EKS cluster.

# host: gets the EKS Kubernetes API server endpoint from the existing cluster.
#host = data.aws_eks_cluster.cluster.endpoint

# cluster_ca_certificate: gets the CA certificate from the list ([0] = first item), extracts .data, and decodes the Base64-encoded certificate.
#cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

# token: gets a temporary authentication token for accessing the EKS cluster.
#token = data.aws_eks_cluster_auth.cluster.token

provider "kubernetes" {
    host = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token = data.aws_eks_cluster_auth.cluster.token
}

# Helm provider: allows Terraform to install and manage Helm charts inside the EKS cluster. So we need to authenticate to EKS 
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}