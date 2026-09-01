output "ssm_arn" {
  value = aws_ssm_parameter.watchfloor_db_url.arn
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}
