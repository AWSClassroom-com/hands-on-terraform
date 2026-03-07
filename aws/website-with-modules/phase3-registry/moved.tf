# Phase 3: Custom load-balancer module → Registry ALB module address mappings
#
# The terraform-aws-modules/alb/aws registry module creates resources
# internally using count and for_each with map keys we control:
#   - aws_lb.this[0]                       (count)
#   - aws_lb_target_group.this["<key>"]    (for_each over target_groups map)
#   - aws_lb_listener.this["<key>"]        (for_each over listeners map)
#
# Our Phase 2 custom load-balancer module used simple resource names:
#   - aws_lb.web_alb
#   - aws_lb_target_group.web_tg
#   - aws_lb_listener.web_listener
#
# All three resource types match exactly, so moved blocks achieve
# a zero-change plan.

# --- Application Load Balancer ---
moved {
  from = module.load_balancer.aws_lb.web_alb
  to   = module.load_balancer.aws_lb.this[0]
}

# --- Target Group ---
moved {
  from = module.load_balancer.aws_lb_target_group.web_tg
  to   = module.load_balancer.aws_lb_target_group.this["web_tg"]
}

# --- Listener ---
moved {
  from = module.load_balancer.aws_lb_listener.web_listener
  to   = module.load_balancer.aws_lb_listener.this["web_listener"]
}
