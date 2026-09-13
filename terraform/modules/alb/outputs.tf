output "target_group_arn" {
  value      = aws_lb_target_group.main.arn
  depends_on = [aws_lb_listener.main]
}
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}
