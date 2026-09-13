output "cluster_name" {
  value = module.ecs.cluster_name
}

output "service_name" {
  value = module.ecs.service_name
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "repository_url" {
  value = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.main.arn
}

output "distribution_domain_name" {
  value = one(module.cloudfront[*].distribution_domain_name)
}
