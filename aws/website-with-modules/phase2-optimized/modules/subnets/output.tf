output "subnet_ids" {
  value = values(aws_subnet.subnets)[*].id
}

output "subnet_ids_by_az" {
  value = { for k, v in aws_subnet.subnets : k => v.id }
}

output "route_table_id" {
  value = aws_route_table.rt.id
}