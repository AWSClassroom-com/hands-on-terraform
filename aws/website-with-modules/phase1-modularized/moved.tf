moved {
  from = aws_s3_bucket.bucket
  to   = module.s3_bucket.aws_s3_bucket.bucket
}
moved {
  from = aws_s3_bucket_ownership_controls.this
  to   = module.s3_bucket.aws_s3_bucket_ownership_controls.this
}
moved {
  from = aws_s3_bucket_public_access_block.this
  to   = module.s3_bucket.aws_s3_bucket_public_access_block.this
}
moved {
  from = aws_s3_bucket_versioning.versioning
  to   = module.s3_bucket.aws_s3_bucket_versioning.versioning
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.encryption
  to   = module.s3_bucket.aws_s3_bucket_server_side_encryption_configuration.encryption
}

moved {
  from = aws_vpc.custom-vpc
  to   = module.networking.aws_vpc.custom-vpc
}
moved {
  from = aws_subnet.public_subnets
  to   = module.networking.aws_subnet.public_subnets
}
moved {
  from = aws_internet_gateway.igw
  to   = module.networking.aws_internet_gateway.igw
}
moved {
  from = aws_nat_gateway.ngw
  to   = module.networking.aws_nat_gateway.ngw
}
moved {
  from = aws_route_table.public_rt
  to   = module.networking.aws_route_table.public_rt
}
moved {
  from = aws_route_table_association.public_assoc
  to   = module.networking.aws_route_table_association.public_assoc
}
moved {
  from = aws_subnet.private_subnets
  to   = module.networking.aws_subnet.private_subnets
}
moved {
  from = aws_route_table.private_rt
  to   = module.networking.aws_route_table.private_rt
}
moved {
  from = aws_route_table_association.private_assoc
  to   = module.networking.aws_route_table_association.private_assoc
}

moved {
  from = aws_security_group.allow-http-ssh
  to   = module.security_groups.aws_security_group.allow-http-ssh
}
moved {
  from = aws_vpc_security_group_ingress_rule.allow-http-ipv4
  to   = module.security_groups.aws_vpc_security_group_ingress_rule.allow-http-ipv4
}
moved {
  from = aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
  to   = module.security_groups.aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
}
moved {
  from = aws_vpc_security_group_egress_rule.allow-all-outbound
  to   = module.security_groups.aws_vpc_security_group_egress_rule.allow-all-outbound
}
moved {
  from = aws_security_group.alb_sg
  to   = module.security_groups.aws_security_group.alb_sg
}
moved {
  from = aws_vpc_security_group_ingress_rule.alb_http_in
  to   = module.security_groups.aws_vpc_security_group_ingress_rule.alb_http_in
}
moved {
  from = aws_vpc_security_group_egress_rule.alb_all_out
  to   = module.security_groups.aws_vpc_security_group_egress_rule.alb_all_out
}

moved {
  from = aws_lb.web_alb
  to   = module.load_balancer.aws_lb.web_alb
}
moved {
  from = aws_lb_target_group.web_tg
  to   = module.load_balancer.aws_lb_target_group.web_tg
}
moved {
  from = aws_lb_listener.web_listener
  to   = module.load_balancer.aws_lb_listener.web_listener
}

moved {
  from = aws_launch_template.web_template
  to   = module.autoscaling_group.aws_launch_template.web_template
}
moved {
  from = aws_autoscaling_group.web_asg
  to   = module.autoscaling_group.aws_autoscaling_group.web_asg
}