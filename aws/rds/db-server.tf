resource "aws_db_subnet_group" "rds" {
  name       = var.db_subnet_group_name
  subnet_ids = [aws_subnet.db_subnet_a.id, aws_subnet.db_subnet_b.id]
  tags       = { Name = var.db_subnet_group_name }
}

# --- Security Group (Modern Rules) ---
resource "aws_security_group" "rds" {
  name        = var.rds_security_group_name
  description = "Allow Postgres Access"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = { Name = var.rds_security_group_name }
}

# Allow Postgres from existing app/web security group
resource "aws_vpc_security_group_ingress_rule" "postgres_from_app_sg" {
  security_group_id = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.allow-http-ssh.id
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.rds.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- RDS Postgres ---
resource "aws_db_instance" "postgres" {
  identifier        = var.db_identifier
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username

  # Modern Security: Let AWS manage the password in Secrets Manager
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Lab settings for easy destruction
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = var.db_identifier }
}
