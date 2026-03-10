resource "aws_vpc" "custom-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.account}-${var.vpc_name}"
  }
}

resource "aws_subnet" "public_subnets" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.account}-${var.vpc_name}-public-${each.key}"
  }
}

moved {
  from = aws_subnet.subnet-a
  to   = aws_subnet.public_subnets["<your-az-here>"] # e.g. us-east-1a
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.account}-${var.vpc_name}-igw"
  }
}

resource "aws_nat_gateway" "ngw" {
  vpc_id            = aws_vpc.custom-vpc.id
  availability_mode = "regional"
  connectivity_type = "public"
  depends_on        = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.account}-${var.vpc_name}-ngw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.account}-${var.route_table_name}"
  }
}

# Update the Route Table Association to also use a loop
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# Add a moved block for the existing association too!
moved {
  from = aws_route_table_association.public_subnet_a
  to   = aws_route_table_association.public_assoc["<your-az-here>"]
}