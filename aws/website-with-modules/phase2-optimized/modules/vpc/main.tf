resource "aws_vpc" "custom-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
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