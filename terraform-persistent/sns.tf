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
