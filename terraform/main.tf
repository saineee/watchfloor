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

module "ecs" {
  source                       = "./modules/ecs"
  name_prefix                  = var.name_prefix
  private_subnet_ids           = module.vpc.private_subnet_ids
  security_group_id            = module.security.ecs_task_sg_id
  target_group_arn             = module.alb.target_group_arn
  image                        = "${aws_ecr_repository.main.repository_url}:${var.image_tag}"
  database_url_ssm_arn         = module.rds.ssm_arn
  anthropic_federation_rule_id = var.anthropic_federation_rule_id
  anthropic_organization_id    = var.anthropic_organization_id
  anthropic_service_account_id = var.anthropic_service_account_id
  anthropic_workspace_id       = var.anthropic_workspace_id
}
