data "aws_ecr_repository" "api" {
  name = "${var.name_prefix}-api"
}
