# Security group for RDS allowing access from ECS tasks
resource "aws_security_group" "dojo_rds_sg" {
  name        = "${var.prefix}-${var.environment}-rds-sg"
  description = "Security group for RDS allowing access from backend tasks"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dojo-rds-sg"
  }
}

# ECS security group on port 8000 to allow from backend to frontend
resource "aws_security_group" "backend_sg" {
  name        = "${var.prefix}-${var.environment}-backend-sg"
  description = "Security group for ECS tasks from backend allowing access on port 8000 from frontend"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]]
    security_groups = [aws_security_group.frontend_sg.id] # Allow access from ALB security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dojo-backend-sg"
  }
}

resource "aws_security_group" "frontend_sg" {
  name        = "${var.prefix}-${var.environment}-frontend-sg"
  description = "Security group for ECS tasks from frontend allowing access on port 80 from alb"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]]
    security_groups = [aws_security_group.dojo_alb_sg.id] # Allow access from ALB security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dojo-frontend-sg"
  }
}

# ALB security group allowing access on port 80 and 443 
resource "aws_security_group" "dojo_alb_sg" {
  name        = "${var.prefix}-${var.environment}-alb-sg"
  description = "Security group for alb allowing access on port 80 and 443"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dojo-alb-sg"
  }
}
