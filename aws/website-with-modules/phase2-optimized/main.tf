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

  account = var.account
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

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id              = module.vpc.vpc_id
  security_group_name = var.security_group_name
  account             = var.account
}

module "load_balancer" {
  source = "./modules/load-balancer"

  account           = var.account
  vpc_id            = module.vpc.vpc_id
  alb_sg_id         = module.security_groups.alb_sg_id
  public_subnet_ids = module.public_subnets.subnet_ids
}

module "autoscaling_group" {
  source = "./modules/autoscaling-group"

  account            = var.account
  image_id           = var.image_id[var.region]
  instance_type      = var.instance_type
  instance_count_min = var.instance_count_min
  instance_count_max = var.instance_count_max
  user_data_base64   = filebase64("${path.module}/install_space_invaders.sh")
  app_sg_id          = module.security_groups.app_sg_id
  private_subnet_ids = module.private_subnets.subnet_ids
  target_group_arn   = module.load_balancer.target_group_arn
}