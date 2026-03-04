output "app_sg_id" {
  value = aws_security_group.allow-http-ssh.id
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}