data "aws_ecr_repository" "api" {
  name = "${var.name_prefix}-api"
}

data "aws_ecr_image" "api" {
  repository_name = data.aws_ecr_repository.api.name
  most_recent     = true
}
