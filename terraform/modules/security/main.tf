resource "aws_security_group" "alb_sg" {
  vpc_id = var.vpc_id
  name   = "${var.name_prefix}-alb-sg"
}

resource "aws_vpc_security_group_ingress_rule" "alb_sg_ingress" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_sg_egress" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "ecs_task_sg" {
  vpc_id = var.vpc_id
  name   = "${var.name_prefix}-ecs-task-sg"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_task_sg_ingress" {
  security_group_id            = aws_security_group.ecs_task_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_task_sg_ingress_prom" {
  security_group_id            = aws_security_group.ecs_task_sg.id
  referenced_security_group_id = aws_security_group.other_sgs["prometheus"].id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_task_sg_egress" {
  security_group_id = aws_security_group.ecs_task_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "rds_sg" {
  vpc_id = var.vpc_id
  name   = "${var.name_prefix}-rds-sg"
}

resource "aws_vpc_security_group_ingress_rule" "rds_sg_ingress" {
  security_group_id            = aws_security_group.rds_sg.id
  referenced_security_group_id = aws_security_group.ecs_task_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

locals {
  sgs        = ["prometheus", "alertmanager", "efs_mnt", "grafana"]
  egress_sgs = ["prometheus", "alertmanager", "grafana"]
}

resource "aws_security_group" "other_sgs" {
  vpc_id   = var.vpc_id
  for_each = toset(local.sgs)
  name     = "${var.name_prefix}-${each.key}-sg"
}

resource "aws_vpc_security_group_ingress_rule" "prometheus" {
  security_group_id            = aws_security_group.other_sgs["prometheus"].id
  referenced_security_group_id = aws_security_group.other_sgs["grafana"].id
  from_port                    = 9090
  to_port                      = 9090
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alertmanager" {
  security_group_id            = aws_security_group.other_sgs["alertmanager"].id
  referenced_security_group_id = aws_security_group.other_sgs["prometheus"].id
  from_port                    = 9093
  to_port                      = 9093
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "efs_mnt" {
  security_group_id            = aws_security_group.other_sgs["efs_mnt"].id
  referenced_security_group_id = aws_security_group.other_sgs["prometheus"].id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "obs" {
  for_each          = toset(local.egress_sgs)
  security_group_id = aws_security_group.other_sgs[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
