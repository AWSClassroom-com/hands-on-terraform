data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "custom-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "subnet-a" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = var.public_subnet_a_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_nat_gateway" "ngw" {
  vpc_id            = aws_vpc.custom-vpc.id
  availability_mode = "regional"
  connectivity_type = "public"
  depends_on        = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.vpc_name}-ngw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = var.route_table_name
  }
}

resource "aws_route_table_association" "public_subnet_a" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.public_rt.id
}

