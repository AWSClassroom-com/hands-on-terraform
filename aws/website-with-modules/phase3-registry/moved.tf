# Phase 3: Custom SG module → Registry module address mappings
#
# The terraform-aws-modules/security-group/aws registry module creates
# its security group as aws_security_group.this[0] internally.
# Our Phase 2 custom module used aws_security_group.this (no index).
#
# Ingress/egress rules in the registry module use different resource
# types (aws_security_group_rule) vs our Phase 2 VPC security group
# rules (aws_vpc_security_group_ingress_rule / egress_rule).
#
# Because the registry module uses aws_security_group_rule (classic)
# while Phase 2 used aws_vpc_security_group_*_rule (VPC-native),
# the rule resources CANNOT be moved — they are different resource types.
# Only the security group resources themselves can be moved.
# Terraform will destroy the old VPC-native rules and create new
# classic rules — this is expected and unavoidable.

# --- ALB Security Group ---
moved {
  from = module.alb_security_group.aws_security_group.this
  to   = module.alb_security_group.aws_security_group.this[0]
}

# --- App Security Group ---
moved {
  from = module.app_security_group.aws_security_group.this
  to   = module.app_security_group.aws_security_group.this[0]
}
