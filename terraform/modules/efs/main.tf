data "aws_efs_file_system" "prom_data" {
  creation_token = "${var.name_prefix}-prometheus"
}

resource "aws_efs_mount_target" "prom_mnt" {
  count           = length(var.private_subnets_ids)
  file_system_id  = data.aws_efs_file_system.prom_data.id
  subnet_id       = var.private_subnets_ids[count.index]
  security_groups = [var.efs_sg_id]
}
