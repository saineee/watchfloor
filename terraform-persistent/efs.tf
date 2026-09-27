resource "aws_efs_file_system" "prom_data" {
  creation_token = "${var.name_prefix}-prometheus"
  encrypted      = true
  tags = {
    Name = "PromFS"
  }
  lifecycle {
    prevent_destroy = true
  }
}
