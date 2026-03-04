# ------------------------
# Existing App SG (Updated Rules)
# ------------------------
resource "aws_security_group" "allow-http-ssh" {
  name        = var.security_group_name
  description = "Enable HTTP and SSH Access"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-http-ipv4" {
  security_group_id            = aws_security_group.allow-http-ssh.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh-ipv4" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow-all-outbound" {
  security_group_id = aws_security_group.allow-http-ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------
# ALB SG (Internet Facing)
# ------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.account}-alb-sg"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = {
    Name = "${var.account}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}