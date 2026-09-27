output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "ecs_task_sg_id" {
  value = aws_security_group.ecs_task_sg.id
}

output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}

output "sec_group_ids" {
  value = { for k, sg in aws_security_group.other_sgs : k => sg.id }
}
