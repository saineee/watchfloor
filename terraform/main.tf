module "vpc" {
  source      = "./modules/vpc"
  name_prefix = var.name_prefix
}

module "security" {
  source      = "./modules/security"
  vpc_id      = module.vpc.vpc_id
  name_prefix = var.name_prefix
}

module "rds" {
  source             = "./modules/rds"
  name_prefix        = var.name_prefix
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.security.rds_sg_id
}

module "alb" {
  source            = "./modules/alb"
  name_prefix       = var.name_prefix
  public_subnet_ids = module.vpc.public_subnet_ids
  vpc_id            = module.vpc.vpc_id
  security_group_id = module.security.alb_sg_id
}
