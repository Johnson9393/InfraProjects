# Security group for RDS allowing access from ECS tasks
resource "aws_security_group" "sp_rds_sg" {
  name        = "sp-rds-sg"
  description = "Security group for RDS allowing access from ECS tasks"
  vpc_id      = aws_vpc.sp_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sp_ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sp-rds-sg"
  }
}

# ECS security group on port 8000 for app access
resource "aws_security_group" "sp_ecs_sg" {
  name        = "sp-ecs-sg"
  description = "Security group for ECS tasks allowing access on port 8000"
  vpc_id      = aws_vpc.sp_vpc.id

  ingress {
    from_port = 8000
    to_port   = 8000
    protocol  = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]]
    security_groups = [aws_security_group.sp_alb_sg.id] # Allow access from ALB security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sp-ecs-sg"
  }
}

# ALB security group allowing access on port 80 and 443 
resource "aws_security_group" "sp_alb_sg" {
  name        = "sp-alb-sg"
  description = "Security group for alb allowing access on port 80 and 443"
  vpc_id      = aws_vpc.sp_vpc.id

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
    Name = "sp-alb-sg"
  }
}
