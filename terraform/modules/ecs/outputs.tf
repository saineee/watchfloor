output "cluster_name" {
  value = aws_ecs_cluster.main.name
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
