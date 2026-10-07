resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for the EKS control plane"
  vpc_id      = var.vpc_id

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}


resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-node-sg"
  })
}

# Cluster to Nodes communication path
resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_cluster.id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# Nodes to Cluster communication path
resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes" {
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = aws_security_group.eks_nodes.id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# Node - Node communication path
resource "aws_vpc_security_group_ingress_rule" "nodes_from_nodes" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_nodes.id

  ip_protocol = "-1"
}