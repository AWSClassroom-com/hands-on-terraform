moved {
  from = module.networking.aws_vpc.custom-vpc
  to   = module.vpc.aws_vpc.custom-vpc
}
moved {
  from = module.networking.aws_internet_gateway.igw
  to   = module.vpc.aws_internet_gateway.igw
}
moved {
  from = module.networking.aws_nat_gateway.ngw
  to   = module.vpc.aws_nat_gateway.ngw
}

moved {
  from = module.networking.aws_subnet.public_subnets
  to   = module.public_subnets.aws_subnet.subnets
}
moved {
  from = module.networking.aws_route_table.public_rt
  to   = module.public_subnets.aws_route_table.rt
}
moved {
  from = module.networking.aws_route_table_association.public_assoc
  to   = module.public_subnets.aws_route_table_association.assoc
}

moved {
  from = module.networking.aws_subnet.private_subnets[0]
  to   = module.private_subnets.aws_subnet.subnets["us-east-2a"]
}
moved {
  from = module.networking.aws_subnet.private_subnets[1]
  to   = module.private_subnets.aws_subnet.subnets["us-east-2b"]
}
moved {
  from = module.networking.aws_subnet.private_subnets[2]
  to   = module.private_subnets.aws_subnet.subnets["us-east-2c"]
}
moved {
  from = module.networking.aws_route_table.private_rt
  to   = module.private_subnets.aws_route_table.rt
}
moved {
  from = module.networking.aws_route_table_association.private_assoc[0]
  to   = module.private_subnets.aws_route_table_association.assoc["us-east-2a"]
}
moved {
  from = module.networking.aws_route_table_association.private_assoc[1]
  to   = module.private_subnets.aws_route_table_association.assoc["us-east-2b"]
}
moved {
  from = module.networking.aws_route_table_association.private_assoc[2]
  to   = module.private_subnets.aws_route_table_association.assoc["us-east-2c"]
}