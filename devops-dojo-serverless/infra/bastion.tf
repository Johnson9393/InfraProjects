#############################################
# Amazon Linux 2023 AMI
#############################################

data "aws_ami" "bastion_ami" {

  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#############################################
# Bastion IAM Role
#############################################

resource "aws_iam_role" "bastion_role" {

  name = "${var.prefix}-${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

#############################################
# SSM
#############################################

resource "aws_iam_role_policy_attachment" "bastion_ssm" {

  role       = aws_iam_role.bastion_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################################
# Instance Profile
#############################################

resource "aws_iam_instance_profile" "bastion_profile" {

  name = "${var.prefix}-${var.environment}-bastion-profile"

  role = aws_iam_role.bastion_role.name
}

#############################################
# Bastion EC2
#############################################

module "bastion" {

  source = "../modules/ec2"

  name = "${var.prefix}-${var.environment}-bastion"

  ami_id = data.aws_ami.bastion_ami.id

  associate_public_ip_address = true

  instance_type = var.bastion_instance_type

  subnet_id = module.network.public_subnet_ids[0]

  security_group_ids = [
    aws_security_group.bastion_sg.id
  ]

  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name

  tags = {
    Name        = "${var.prefix}-${var.environment}-bastion"
    Project     = var.project
    Environment = var.environment
  }
}