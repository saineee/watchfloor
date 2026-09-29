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
  image                        = "${data.aws_ecr_repository.api.repository_url}:${var.image_tag}"
  database_url_ssm_arn         = module.rds.ssm_arn
  anthropic_federation_rule_id = var.anthropic_federation_rule_id
  anthropic_organization_id    = var.anthropic_organization_id
  anthropic_service_account_id = var.anthropic_service_account_id
  anthropic_workspace_id       = var.anthropic_workspace_id
  secret_key_ssm_arn           = aws_ssm_parameter.fastapi_secret_key.arn
  permissions_boundary         = local.permissions_boundary
  account_id                   = data.aws_caller_identity.current.account_id
}

resource "random_password" "secret_key" {
  length  = 32
  special = true
}

resource "aws_ssm_parameter" "fastapi_secret_key" {
  name  = "/${var.name_prefix}/SECRET_KEY"
  type  = "SecureString"
  value = random_password.secret_key.result
}

resource "random_password" "grafana_pass" {
  length  = 16
  special = true
}

resource "aws_ssm_parameter" "grafana_pass" {
  name  = "/${var.name_prefix}/GF_SECURITY_ADMIN_PASSWORD"
  type  = "SecureString"
  value = random_password.grafana_pass.result
}

module "cloudfront" {
  count        = var.enable_cloudfront ? 1 : 0
  source       = "./modules/cloudfront"
  alb_dns_name = module.alb.alb_dns_name
  name_prefix  = var.name_prefix
}

module "cloudmap" {
  source = "./modules/cloudmap"
  vpc_id = module.vpc.vpc_id
}

module "efs" {
  source              = "./modules/efs"
  name_prefix         = var.name_prefix
  private_subnets_ids = module.vpc.private_subnet_ids
  efs_sg_id           = module.security.sec_group_ids["efs_mnt"]
}

module "observability" {
  source               = "./modules/observability"
  name_prefix          = var.name_prefix
  permissions_boundary = local.permissions_boundary
  graf_pass_arn        = aws_ssm_parameter.grafana_pass.arn
  account_id           = data.aws_caller_identity.current.account_id
  prom_cloudmap        = module.cloudmap.registry_arns["prometheus"]
  graf_cloudmap        = module.cloudmap.registry_arns["grafana"]
  am_cloudmap          = module.cloudmap.registry_arns["alertmanager"]
  cluster_arn          = module.ecs.cluster_arn
  private_subnets_ids  = module.vpc.private_subnet_ids
  alertmanager_sg      = module.security.sec_group_ids["alertmanager"]
}

data "aws_caller_identity" "current" {}

locals {
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name_prefix}-app-boundary"
}
