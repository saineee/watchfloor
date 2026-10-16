data "aws_ecr_repository" "api" {
  name = "${var.name_prefix}-api"
}

data "aws_ecr_image" "api" {
  repository_name = data.aws_ecr_repository.api.name
  most_recent     = true
}

data "aws_s3_bucket" "frontend" {
  bucket = "${var.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
}
