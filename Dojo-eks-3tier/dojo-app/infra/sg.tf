# Security group for RDS allowing access from EKS backend
resource "aws_security_group" "dojo_rds_sg" {
  name        = "${var.project}-${var.env}-rds-sg"
  description = "Security group for RDS allowing access from backend service"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    //security_groups = ["0.0.0.0/0"] # later add eks node sg
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-rds-sg"
  }
}