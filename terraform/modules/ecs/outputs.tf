output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "task_arn_prefix" {
  value = replace(aws_ecs_cluster.main.arn, ":cluster/", ":task/")
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.main.arn_without_revision
}

output "service_name" {
  value = aws_ecs_service.main.name
}

output "exec_role" {
  value = aws_iam_role.exec_role.arn
}

output "task_role" {
  value = aws_iam_role.ecs_task_role.arn
}

output "service_arn" {
  value = aws_ecs_service.main.arn
}
