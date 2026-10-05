data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "github_deploy" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:saineee@52940016/watchfloor@1344674191:ref:refs/tags/v*"
        }
      }
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
    }]
    Version = "2012-10-17"
  })
  name = "${var.name_prefix}-github-deploy"
}

resource "aws_iam_role" "github_obs_deploy_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:saineee@52940016/watchfloor@1344674191:ref:refs/heads/main"
        }
      }
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
    }]
    Version = "2012-10-17"
  })
  name = "${var.name_prefix}-github-obs-deploy"
}

resource "aws_iam_role_policy" "github_obs_role_policy" {
  name = "${var.name_prefix}-github-obs-deploy-policy"
  role = aws_iam_role.github_obs_deploy_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
      Effect   = "Allow"
      Resource = "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${var.name_prefix}-obs-*"
      Sid      = "ecrCollectionObs" }, {
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "watchfloorGetAuthToken"
    }]
  })
}

resource "aws_iam_role_policy" "github_deploy_role_policy" {
  name = "${var.name_prefix}-github-deploy-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
      Effect   = "Allow"
      Resource = "*"
      Sid      = "ecsRegisterDescribe"
      }, {
      Action   = ["ecs:UpdateService", "ecs:DescribeServices"]
      Effect   = "Allow"
      Resource = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/${var.name_prefix}-cluster/${var.name_prefix}-service"
      Sid      = "ecsUpdateDescribe"
      }, {
      Action = "iam:PassRole"
      Condition = {
        StringEquals = {
          "iam:PassedToService" : "ecs-tasks.amazonaws.com"
        }
      }
      Effect   = "Allow"
      Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-task-role", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-exec-role"]
      Sid      = "watchfloorECSPassRole"
      }, {
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "watchfloorGetAuthToken"
      }, {
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:DescribeImages"]
      Effect   = "Allow"
      Resource = "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${var.name_prefix}-api"
      Sid      = "ecrCollection"
      }, {
      Action = "ecs:RunTask"
      Condition = {
        StringEquals = {
          "ecs:cluster" : "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.name_prefix}-cluster"
        }
      }
      Effect   = "Allow"
      Resource = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.name_prefix}-api:*"
      Sid      = "watchfloorRunTask"
      }, {
      Action   = "ecs:DescribeTasks"
      Effect   = "Allow"
      Resource = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task/${var.name_prefix}-cluster/*"
      Sid      = "watchfloorDescTasks"
    }]
  })
  role = aws_iam_role.github_deploy.name
}

resource "aws_iam_role" "github_actions_ro" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:saineee@52940016/watchfloor@1344674191:pull_request"
        }
      }
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      }
  ] })

  name = "${var.name_prefix}-read-only"
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.github_actions_ro.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

//bucket and key must match backend "s3" block
locals {
  lock_file_arn = "arn:aws:s3:::watchfloor-tfstate-330866750121/watchfloor/backend/terraform.tfstate.tflock"
}

resource "aws_iam_role_policy" "s3_state_lock" {
  role = aws_iam_role.github_actions_ro.id
  name = "${var.name_prefix}-s3-state-lock"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
        "s3:PutObject", "s3:DeleteObject"]
        Effect   = "Allow"
        Resource = local.lock_file_arn
    }]
  })
}

resource "aws_iam_policy" "boundary" {
  name = "${var.name_prefix}-app-boundary"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
        ]
        Effect   = "Allow"
        Resource = "*"
        }, {
        Action = [
          "ssm:GetParameters",
          "sts:GetWebIdentityToken",
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Effect   = "Allow"
        Resource = "*"
        }, {
        Action   = ["sns:Publish"]
        Effect   = "Allow"
        Resource = "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:${var.name_prefix}-*"
        }, {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ],
  })
}

resource "aws_iam_role" "github_apply" {
  name = "${var.name_prefix}-apply-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:saineee@52940016/watchfloor@1344674191:environment:production"
          }
        }
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "power_user" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "github_apply_policy" {
  name = "${var.name_prefix}-github-apply-policy"
  role = aws_iam_role.github_apply.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["iam:CreateRole", "iam:AttachRolePolicy", "iam:PutRolePolicy"]
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = aws_iam_policy.boundary.arn
          }
        }
        Effect   = "Allow"
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-*"]
        }, {
        Action = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:TagRole", "iam:UntagRole", "iam:UpdateAssumeRolePolicy", "iam:DetachRolePolicy",
        "iam:DeleteRolePolicy", "iam:DeleteRole", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole"]
        Effect   = "Allow"
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-*"]
        }, {
        Action = "iam:PassRole"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
        Effect   = "Allow"
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-*"]
        }, {
        Action   = ["iam:PutRolePermissionsBoundary", "iam:DeleteRolePermissionsBoundary"]
        Effect   = "Deny"
        Resource = "*"
        }, {
        Action   = ["iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:DeletePolicyVersion", "iam:DeletePolicy"]
        Effect   = "Deny"
        Resource = aws_iam_policy.boundary.arn
        }, {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}/${var.name_prefix}/backend/*"
        }, {
        Action = "s3:ListBucket"
        Condition = {
          StringLike = {
            "s3:prefix" = ["${var.name_prefix}/backend", "${var.name_prefix}/backend/*"]
          }
        }
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
    }]
  })
}
