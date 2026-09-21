resource "aws_sns_topic" "page" {
  name = "${var.name_prefix}-AM_Page"
}

resource "aws_sns_topic" "ticket" {
  name = "${var.name_prefix}-AM_Ticket"
}

resource "aws_sns_topic_subscription" "page" {
  topic_arn = aws_sns_topic.page.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_sns_topic_subscription" "ticket" {
  topic_arn = aws_sns_topic.ticket.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_iam_role" "alertmanager_role" {
  name = "${var.name_prefix}-alertmanager-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          "AWS" : var.paul_user
        }
    }]
  })
}

resource "aws_iam_role_policy" "alert_pub" {
  name = "${var.name_prefix}-am-pub"
  role = aws_iam_role.alertmanager_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["sns:Publish"]
      Effect   = "Allow"
      Resource = [aws_sns_topic.ticket.arn, aws_sns_topic.page.arn]
    }]
  })
}
