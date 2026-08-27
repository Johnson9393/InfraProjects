data "aws_ecr_repository" "backend" {
  name = "${var.project}-${var.env}-backend"
}

data "aws_ecr_repository" "frontend" {
  name = "${var.project}-${var.env}-frontend"
}