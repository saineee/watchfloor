output "file_system_id" {
  value = data.aws_efs_file_system.prom_data.id
}

output "prom_efs_access_point" {
  value = aws_efs_access_point.prometheus.id
}
