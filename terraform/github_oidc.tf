data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_deploy" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:saineee/watchfloor:ref:refs/tags/v*"
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
      Resource = module.ecs.service_arn
      Sid      = "ecsUpdateDescribe"
      }, {
      Action = "iam:PassRole"
      Condition = {
        StringEquals = {
          "iam:PassedToService" : "ecs-tasks.amazonaws.com"
        }
      }
      Effect   = "Allow"
      Resource = [module.ecs.task_role, module.ecs.exec_role]
      Sid      = "watchfloorECSPassRole"
      }, {
      Action   = "ecr:GetAuthorizationToken"
      Effect   = "Allow"
      Resource = "*"
      Sid      = "watchfloorGetAuthToken"
      }, {
      Action   = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
      Effect   = "Allow"
      Resource = aws_ecr_repository.main.arn
      Sid      = "ecrCollection"
    }]
  })
  role = aws_iam_role.github_deploy.name
}
