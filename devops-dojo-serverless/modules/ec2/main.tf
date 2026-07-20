resource "aws_instance" "main" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  associate_public_ip_address = var.associate_public_ip_address

  iam_instance_profile = var.iam_instance_profile

  tags = merge(
    var.tags,
    {
      Name        = var.name
      Role        = "Bastion"
    }
  )
}
