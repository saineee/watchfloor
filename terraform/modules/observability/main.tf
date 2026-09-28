locals {
  obs = ["prometheus", "grafana", "alertmanager"]
}

resource "aws_cloudwatch_log_group" "obs" {
  for_each          = toset(local.obs)
  name              = "/ecs/${var.name_prefix}/obs/${each.key}"
  retention_in_days = 7
}
