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
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.account}-alb-sg"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = var.security_group_name
  description = "Enable HTTP and SSH Access"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "load_balancer" {
  source = "./modules/load-balancer"

  account            = var.account
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.public_subnets.subnet_ids
  security_group_ids = [module.alb_security_group.security_group_id]
}

module "autoscaling_group" {
  source = "./modules/autoscaling-group"

  instance_type       = var.instance_type
  instance_count_max  = var.instance_count_max
  target_group_arns   = [module.load_balancer.target_group_arn]
  subnet_ids          = module.private_subnets.subnet_ids
  security_group_ids  = [module.app_security_group.security_group_id]
  user_data_base64    = filebase64("${path.root}/install_space_invaders.sh")
}
