locals {
  obs = ["prometheus", "grafana", "alertmanager"]
}

data "aws_sns_topic" "page" {
  name = "${var.name_prefix}-AM_Page"
}

data "aws_sns_topic" "ticket" {
  name = "${var.name_prefix}-AM_Ticket"
}

data "aws_ecr_image" "obs" {
  for_each        = toset(local.obs)
  repository_name = "${var.name_prefix}-obs-${each.key}"
  most_recent     = true
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

resource "aws_ecs_task_definition" "alertmanager" {
  family                   = "${var.name_prefix}-obs-alertmanager"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.obs_exec.arn
  task_role_arn            = aws_iam_role.alertmanager_task_role.arn
  memory                   = tostring(var.memory)
  cpu                      = tostring(var.cpu)
  container_definitions = jsonencode(
    [
      {
        name      = "${var.name_prefix}-obs-alertmanager"
        image     = data.aws_ecr_image.obs["alertmanager"].image_uri
        essential = true
        healthCheck = {
          command     = ["CMD-SHELL", "wget --spider -q http://localhost:9093/-/healthy || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 15
        }
        portMappings = [{ containerPort = 9093 }]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.obs["alertmanager"].name
            "awslogs-region"        = "us-east-1"
            "awslogs-stream-prefix" = "ecs"
          }
        }
      }
    ]
  )
}

resource "aws_ecs_service" "alertmanager" {
  name            = "${var.name_prefix}-obs-alertmanager-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.alertmanager.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [var.alertmanager_sg]
    assign_public_ip = false
  }
  service_registries {
    registry_arn = var.am_cloudmap
  }
}


resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.name_prefix}-obs-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.obs_exec.arn
  memory                   = tostring(var.memory)
  cpu                      = tostring(var.cpu)
  container_definitions = jsonencode(
    [
      {
        name      = "${var.name_prefix}-obs-prometheus"
        image     = data.aws_ecr_image.obs["prometheus"].image_uri
        essential = true
        command = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.external-url=http://prometheus.watchfloor.local:9090"
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "wget --spider -q http://localhost:9090/-/ready || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 15
        }
        mountPoints = [
          {
            sourceVolume  = "prometheus_data"
            containerPath = "/prometheus"
            readOnly      = false
          }
        ]
        portMappings = [{ containerPort = 9090 }]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.obs["prometheus"].name
            "awslogs-region"        = "us-east-1"
            "awslogs-stream-prefix" = "ecs"
          }
        }
      }
    ]
  )
  volume {
    name = "prometheus_data"
    efs_volume_configuration {
      file_system_id     = var.file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.access_point_id
      }
    }
  }
}

resource "aws_ecs_service" "prometheus" {
  name            = "${var.name_prefix}-obs-prometheus-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.private_subnets_ids
    security_groups  = [var.prom_sg]
    assign_public_ip = false
  }
  service_registries {
    registry_arn = var.prom_cloudmap
  }
}
