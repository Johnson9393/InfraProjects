data "aws_vpc" "main" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

# vpc_id - data.aws_vpc.main.id


# ALB created by this ingress
data "aws_lb" "ingress" {
  tags = {
    Name = "${var.sub_domain}-ingress"
  }

  depends_on = [kubernetes_ingress_v1.dojo_htpps_ingress]
}
