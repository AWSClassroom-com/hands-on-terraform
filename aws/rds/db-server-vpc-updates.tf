resource "aws_subnet" "db_subnet_a" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = var.db_subnet_a_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = var.db_subnet_a_name
  }
}

resource "aws_subnet" "db_subnet_b" {
  vpc_id                  = aws_vpc.custom-vpc.id
  cidr_block              = var.db_subnet_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = var.db_subnet_b_name
  }
}

resource "aws_route_table" "db_private_rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = var.db_private_route_table_name
  }
}

resource "aws_route_table_association" "db_subnet_a" {
  subnet_id      = aws_subnet.db_subnet_a.id
  route_table_id = aws_route_table.db_private_rt.id
}

resource "aws_route_table_association" "db_subnet_b" {
  subnet_id      = aws_subnet.db_subnet_b.id
  route_table_id = aws_route_table.db_private_rt.id
}
