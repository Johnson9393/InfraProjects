resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Name = var.vpc_name
  }
}


# Public Subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index].cidr
  availability_zone       = var.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-${var.public_subnets[count.index].prefix}-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public-rt.id
}

######################

# Private Subnets and its association

resource "aws_subnet" "private_subnets" {
  count                   = length(var.private_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnets[count.index].cidr
  map_public_ip_on_launch = false
  availability_zone       = var.private_subnets[count.index].availability_zone

  tags = {
    Name = "${var.vpc_name}-${var.private_subnets[count.index].prefix}-${count.index + 1}"
  }
}

#EIP
# It creates eip based on the need dynamically
resource "aws_eip" "eip_nat" {
  count = var.need_ngw ? var.need_single_ngw ? 1 : length(var.public_subnets) : 0

  tags = {
    Name = "${var.vpc_name}-eip-${count.index + 1}"
  }
}

# NGW
resource "aws_nat_gateway" "ngw" {
  count         = var.need_ngw ? var.need_single_ngw ? 1 : length(var.public_subnets) : 0
  allocation_id = aws_eip.eip_nat[count.index].id
  # subnet_id     = aws_subnet.public_subnets[count.index % length(var.public_subnets)].id # used modulo to avoid index out of range when count logic changes in future
  subnet_id = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "${var.vpc_name}-nat-${count.index + 1}"
  }
}

# Route Table for private subnet
resource "aws_route_table" "private_rt" {
  count  = var.need_ngw ? var.need_single_ngw ? 1 : length(var.public_subnets) : 1
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-rt-${count.index + 1}"
  }
}

# Route for NGW 
resource "aws_route" "route_ngw" {
  count  = var.need_ngw ? var.need_single_ngw ? 1 : length(var.public_subnets) : 0

  route_table_id = aws_route_table.private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.ngw[count.index].id
}

# This handle multi NAT association to multi route tables in multi AZ regions
resource "aws_route_table_association" "private_rt_association" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = var.need_single_ngw ? aws_route_table.private_rt[0].id : aws_route_table.private_rt[count.index].id
}


# RDS Subnets
resource "aws_subnet" "rds_subnets" {
  count = length(var.rds_subnets)

  vpc_id = aws_vpc.main.id
  cidr_block = var.rds_subnets[count.index].cidr
  availability_zone = var.rds_subnets[count.index].availability_zone

  tags = {
    Name = "${var.vpc_name}-${var.rds_subnets[count.index].prefix}-${count.index + 1}"
  }
}
