environment = "dev"

public_subnets = [
  {
    cidr              = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    prefix            = "public"
  },
  {
    cidr              = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    prefix            = "public"
  }
]

private_subnets = [
  {
    cidr              = "10.0.3.0/24"
    availability_zone = "us-east-1a"
    prefix            = "private"
  },
  {
    cidr              = "10.0.4.0/24"
    availability_zone = "us-east-1b"
    prefix            = "private"
  }
]

rds_subnets = [
  {
    cidr              = "10.0.5.0/24"
    availability_zone = "us-east-1a"
    prefix            = "rds"
  },
  {
    cidr              = "10.0.6.0/24"
    availability_zone = "us-east-1b"
    prefix            = "rds"
  }
]


