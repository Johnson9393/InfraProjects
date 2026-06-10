#sp - stands for Student Profile which is a project name

# VPC creation
resource "aws_vpc" "sp_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  region               = var.aws_region

  tags = {
    Name = "sp-vpc"
  }
}

###### Public Network Area #########
# 2 public subnets in 2 different availability zones for high availability
resource "aws_subnet" "sp_public_subnet_1" {
  vpc_id                  = aws_vpc.sp_vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[0] #10.0.1.0/24
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "sp-public-subnet-1"
  }
}

resource "aws_subnet" "sp_public_subnet_2" {
  vpc_id                  = aws_vpc.sp_vpc.id
  cidr_block              = var.public_subnet_cidr_blocks[1] #10.0.2.0/24
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "sp-public-subnet-2"
  }
}

# IGW for internet access
resource "aws_internet_gateway" "sp_igw" {
  vpc_id = aws_vpc.sp_vpc.id
  tags = {
    Name = "sp-igw"
  }
}

# Route table for public subnets
resource "aws_route_table" "sp_public_rt" {
  vpc_id = aws_vpc.sp_vpc.id
  tags = {
    Name = "sp-public-rt"
  }
}

# Route to IGW for public subnets
resource "aws_route" "sp_public_route" {
  route_table_id         = aws_route_table.sp_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sp_igw.id
}

# Route table association for public subnets
resource "aws_route_table_association" "sp_public_subnet_1-assoc" {
  subnet_id      = aws_subnet.sp_public_subnet_1.id
  route_table_id = aws_route_table.sp_public_rt.id
}

resource "aws_route_table_association" "sp_public_subnet_2-assoc" {
  subnet_id      = aws_subnet.sp_public_subnet_2.id
  route_table_id = aws_route_table.sp_public_rt.id
}


# 2 Private subnets in 2 different availability zones for high availability
resource "aws_subnet" "sp_private_subnet_1" {
  vpc_id            = aws_vpc.sp_vpc.id
  cidr_block        = var.private_subnet_cidr_blocks[0] #10.0.3.0/24
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "sp-private-subnet-1"
  }
}

resource "aws_subnet" "sp_private_subnet_2" {
  vpc_id            = aws_vpc.sp_vpc.id
  cidr_block        = var.private_subnet_cidr_blocks[1] #10.0.4.0/24
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "sp-private-subnet-2"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "sp_nat_eip" {
  domain = "vpc"
  tags = {
    Name = "sp-nat-eip"
  }
}

# NAT Gateway in public subnet for private subnet internet access
resource "aws_nat_gateway" "sp_nat_gateway" {
  allocation_id = aws_eip.sp_nat_eip.id
  subnet_id     = aws_subnet.sp_public_subnet_1.id
  tags = {
    Name = "sp-nat-gateway"
  }
}

# Route table for private subnets
resource "aws_route_table" "sp_private_rt" {
  vpc_id = aws_vpc.sp_vpc.id
  tags = {
    Name = "sp-private-rt"
  }
}

# Route to NAT Gateway for private subnets
resource "aws_route" "sp_private_route" {
  route_table_id         = aws_route_table.sp_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.sp_nat_gateway.id
}

# Route table association for private subnets
resource "aws_route_table_association" "sp_private_subnet_1-assoc" {
  subnet_id      = aws_subnet.sp_private_subnet_1.id
  route_table_id = aws_route_table.sp_private_rt.id
}

resource "aws_route_table_association" "sp_private_subnet_2-assoc" {
  subnet_id      = aws_subnet.sp_private_subnet_2.id
  route_table_id = aws_route_table.sp_private_rt.id
}


# RDS Private subnets for database
resource "aws_subnet" "sp_rds_subnet_1" {
  vpc_id            = aws_vpc.sp_vpc.id
  cidr_block        = var.rds_subnet_cidr_blocks[0] #10.0.5.0/24
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "sp-rds-subnet-1"
  }
}

resource "aws_subnet" "sp_rds_subnet_2" {
  vpc_id            = aws_vpc.sp_vpc.id
  cidr_block        = var.rds_subnet_cidr_blocks[1] #10.0.6.0/24
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "sp-rds-subnet-2"
  }
}


