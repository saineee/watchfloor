output "registry_arns" {
  value = { for k, service in aws_service_discovery_service.services : k => service.arn }
}
