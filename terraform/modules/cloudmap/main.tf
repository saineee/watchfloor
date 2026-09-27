resource "aws_service_discovery_private_dns_namespace" "watchfloor" {
  name        = "watchfloor.local"
  description = "dns namespace for app stack"
  vpc         = var.vpc_id
}

locals {
  obs_services = ["prometheus", "grafana", "alertmanager"]
}

resource "aws_service_discovery_service" "services" {
  for_each = toset(local.obs_services)
  name     = each.key
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.watchfloor.id

    dns_records {
      ttl  = 30
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {}
}
