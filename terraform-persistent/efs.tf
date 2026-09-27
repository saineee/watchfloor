resource "aws_efs_file_system" "prom_data" {
  creation_token = "prometheus"

  tags = {
    Name = "PromFS"
  }
}
