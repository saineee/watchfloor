output "cluster_name" {
  value = module.ecs.cluster_name
}

output "service_name" {
  value = module.ecs.service_name
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "distribution_domain_name" {
  value = one(module.cloudfront[*].distribution_domain_name)
}

output "ecr_api_url" {
  value = data.aws_ecr_repository.api.repository_url
}

output "api_repository_arn" {
  value = data.aws_ecr_repository.api.arn
}
