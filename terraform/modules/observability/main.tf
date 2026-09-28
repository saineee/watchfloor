locals {
  obs = ["prometheus", "grafana", "alertmanager"]
}

data "aws_sns_topic" "page" {
  name = "${var.name_prefix}-AM_Page"
}

data "aws_sns_topic" "ticket" {
  name = "${var.name_prefix}-AM_Ticket"
}

resource "aws_cloudwatch_log_group" "obs" {
  for_each          = toset(local.obs)
  name              = "/ecs/${var.name_prefix}/obs/${each.key}"
  retention_in_days = 7
}

resource "aws_iam_role" "obs_exec" {
  name                 = "${var.name_prefix}-ecs-obs-exec"
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "exec_role_attachment" {
  role       = aws_iam_role.obs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "obs_exec_ssm" {
  name = "${var.name_prefix}-exec-role-ssm-policy"
  role = aws_iam_role.obs_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "ssm:GetParameters"
      Effect = "Allow"
      Resource = [
        var.graf_pass_arn
      ]
    }]
  })
}

resource "aws_iam_role" "graf_task_role" {
  name                 = "${var.name_prefix}-ecs-obs-graf-task"
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = var.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "obs_task_graf" {
  name = "${var.name_prefix}-task-role-graf-policy"
  role = aws_iam_role.graf_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "alertmanager_task_role" {
  name                 = "${var.name_prefix}-ecs-obs-alertmanager-task"
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = var.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "obs_task_alertmanager" {
  name = "${var.name_prefix}-task-role-alertmanager-policy"
  role = aws_iam_role.alertmanager_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "sns:Publish"
      ]
      Effect   = "Allow"
      Resource = [data.aws_sns_topic.page.arn, data.aws_sns_topic.ticket.arn]
    }]
  })
}
