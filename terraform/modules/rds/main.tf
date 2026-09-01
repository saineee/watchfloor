resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "-_.~"
}

resource "aws_db_instance" "main" {
  identifier        = "${var.name_prefix}-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [var.security_group_id]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
}

resource "aws_ssm_parameter" "watchfloor_db_url" {
  name  = "/${var.name_prefix}/DATABASE_URL"
  type  = "SecureString"
  value = "postgresql+psycopg://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${aws_db_instance.main.db_name}"
}
