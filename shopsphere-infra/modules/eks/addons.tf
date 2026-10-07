# vpc cni is installed on the eks cluster. hence we added depends_on. Then aws-node daemonset kubernetes workload is managed by that addon. then aws-node pods will be created in each node group. 
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

# kube-proxy is responsible for implementing Kubernetes Service networking on the nodes.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
}

#CoreDNS provides DNS resolution inside the Kubernetes cluster.
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
}
