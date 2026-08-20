provider "aws" {
    region = var.region
    default_tags {
        tags = {
            Environment = "dev"
            Terraform   = "true"
            repo = "terraform-eks-3tier/EKS/eks-core-infra"
        }
    }
}

