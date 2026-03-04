resource "aws_subnet" "subnets" {
  for_each                = var.subnets
  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = var.map_public_ip

  tags = {
    Name = lookup(var.subnet_name_by_az, each.key, "${var.vpc_name}-${var.subnet_name_prefix}-${each.key}")
  }
}

resource "aws_route_table" "rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id     = var.route_target_type == "igw" ? var.route_target_id : null
    nat_gateway_id = var.route_target_type == "nat" ? var.route_target_id : null
  }

  tags = var.route_table_name == null ? {} : {
    Name = var.route_table_name
  }
}

resource "aws_route_table_association" "assoc" {
  for_each       = aws_subnet.subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.rt.id
}