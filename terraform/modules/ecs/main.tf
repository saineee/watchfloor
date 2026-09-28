resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
}

resource "aws_iam_role" "exec_role" {
  name                 = "${var.name_prefix}-ecs-exec-role"
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
  role       = aws_iam_role.exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "exec_role_ssm_policy" {
  name = "${var.name_prefix}-exec-role-ssm-policy"
  role = aws_iam_role.exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "ssm:GetParameters"
      Effect = "Allow"
      Resource = [
        var.database_url_ssm_arn,
        var.secret_key_ssm_arn
      ]
    }]
  })
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  memory                   = tostring(var.memory)
  cpu                      = tostring(var.cpu)
  container_definitions = jsonencode([{
    name         = "${var.name_prefix}-api"
    image        = var.image
    essential    = true
    portMappings = [{ containerPort = var.container_port }]
    secrets = [{
      name      = "DATABASE_URL"
      valueFrom = var.database_url_ssm_arn
      },
      {
        name      = "SECRET_KEY"
        valueFrom = var.secret_key_ssm_arn
    }]
    environment = [
      {
        name  = "ANTHROPIC_FEDERATION_RULE_ID"
        value = var.anthropic_federation_rule_id
      },
      {
        name  = "ANTHROPIC_ORGANIZATION_ID"
        value = var.anthropic_organization_id
      },
      {
        name  = "ANTHROPIC_SERVICE_ACCOUNT_ID"
        value = var.anthropic_service_account_id
      },
      {
        name  = "ANTHROPIC_WORKSPACE_ID"
        value = var.anthropic_workspace_id
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.main.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_iam_role" "ecs_task_role" {
  name                 = "${var.name_prefix}-ecs-task-role"
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_anthropic_policy" {
  name = "${var.name_prefix}-ecs_task_anthropic_policy"
  role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "sts:GetWebIdentityToken"
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_ecs_service" "main" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = var.target_group_arn
    container_port   = var.container_port
    container_name   = "${var.name_prefix}-api"
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
}
