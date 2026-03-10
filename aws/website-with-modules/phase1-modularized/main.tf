module "s3_bucket" {
  source = "./modules/s3-bucket"

  account = var.account
}

module "networking" {
  source = "./modules/networking"

  vpc_cidr         = var.vpc_cidr
  vpc_name         = var.vpc_name
  route_table_name = var.route_table_name
}

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id              = module.networking.vpc_id
  security_group_name = var.security_group_name
  account             = var.account
}

module "load_balancer" {
  source = "./modules/load-balancer"

  account           = var.account
  vpc_id            = module.networking.vpc_id
  alb_sg_id         = module.security_groups.alb_sg_id
  public_subnet_ids = module.networking.public_subnet_ids
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
  private_subnet_ids = module.networking.private_subnet_ids
  target_group_arn   = module.load_balancer.target_group_arn
}