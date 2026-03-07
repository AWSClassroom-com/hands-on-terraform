data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  public_subnets = {
    for i, az in data.aws_availability_zones.available.names :
    az => cidrsubnet(var.vpc_cidr, 4, i)
  }

  private_subnets = {
    for i, az in data.aws_availability_zones.available.names :
    az => cidrsubnet(var.vpc_cidr, 4, i + 10)
  }

  private_subnet_names_by_az = {
    for i, az in data.aws_availability_zones.available.names :
    az => "${var.vpc_name}-private-${i}"
  }
}

module "s3_bucket" {
  source = "./modules/s3-bucket"
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
  vpc_name = var.vpc_name
}

module "public_subnets" {
  source = "./modules/subnets"

  vpc_id             = module.vpc.vpc_id
  vpc_name           = var.vpc_name
  subnets            = local.public_subnets
  map_public_ip      = true
  route_table_name   = var.route_table_name
  route_target_type  = "igw"
  route_target_id    = module.vpc.igw_id
  subnet_name_prefix = "public"
}

module "private_subnets" {
  source = "./modules/subnets"

  vpc_id             = module.vpc.vpc_id
  vpc_name           = var.vpc_name
  subnets            = local.private_subnets
  map_public_ip      = false
  route_table_name   = null
  route_target_type  = "nat"
  route_target_id    = module.vpc.ngw_id
  subnet_name_prefix = "private"
  subnet_name_by_az  = local.private_subnet_names_by_az
}

module "alb_security_group" {
  source = "./modules/security-group"

  name        = "${var.account}-alb-sg"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    alb_http_in = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    alb_all_out = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "app_security_group" {
  source = "./modules/security-group"

  name        = var.security_group_name
  description = "Enable HTTP and SSH Access"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    allow-http-ipv4 = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb_security_group.sg_id
    }
    allow-ssh-ipv4 = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    allow-all-outbound = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "load_balancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name            = "${var.account}-alb"
  vpc_id          = module.vpc.vpc_id
  subnets         = module.public_subnets.subnet_ids
  security_groups = [module.alb_security_group.sg_id]

  create_security_group      = false
  enable_deletion_protection = false
  drop_invalid_header_fields = false

  listeners = {
    web_listener = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "web_tg"
      }
    }
  }

  target_groups = {
    web_tg = {
      name              = "${var.account}-tg"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment  = false

      health_check = {
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        interval            = 30
        matcher             = "200"
      }
    }
  }
}

module "autoscaling_group" {
  source = "./modules/autoscaling-group"

  account            = var.account
  image_id           = var.image_id[var.region]
  instance_type      = var.instance_type
  instance_count_min = var.instance_count_min
  instance_count_max = var.instance_count_max
  user_data_base64   = filebase64("${path.module}/install_space_invaders.sh")
  app_sg_id          = module.app_security_group.sg_id
  private_subnet_ids = module.private_subnets.subnet_ids
  target_group_arn   = module.load_balancer.target_groups["web_tg"].arn
}
