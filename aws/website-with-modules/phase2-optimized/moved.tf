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

moved {
  from = module.security_groups.aws_security_group.alb_sg
  to   = module.alb_security_group.aws_security_group.this
}
moved {
  from = module.security_groups.aws_vpc_security_group_ingress_rule.alb_http_in
  to   = module.alb_security_group.aws_vpc_security_group_ingress_rule.ingress["alb_http_in"]
}
moved {
  from = module.security_groups.aws_vpc_security_group_egress_rule.alb_all_out
  to   = module.alb_security_group.aws_vpc_security_group_egress_rule.egress["alb_all_out"]
}

moved {
  from = module.security_groups.aws_security_group.allow-http-ssh
  to   = module.app_security_group.aws_security_group.this
}
moved {
  from = module.security_groups.aws_vpc_security_group_ingress_rule.allow-http-ipv4
  to   = module.app_security_group.aws_vpc_security_group_ingress_rule.ingress["allow-http-ipv4"]
}
moved {
  from = module.security_groups.aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
  to   = module.app_security_group.aws_vpc_security_group_ingress_rule.ingress["allow-ssh-ipv4"]
}
moved {
  from = module.security_groups.aws_vpc_security_group_egress_rule.allow-all-outbound
  to   = module.app_security_group.aws_vpc_security_group_egress_rule.egress["allow-all-outbound"]
}