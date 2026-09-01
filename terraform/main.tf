module "vpc" {
  source      = "./modules/vpc"
  name_prefix = var.name_prefix
}

module "security" {
  source      = "./modules/security"
  vpc_id      = module.vpc.vpc_id
  name_prefix = var.name_prefix
}
