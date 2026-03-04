output "vpc_id" {
  value = aws_vpc.custom-vpc.id
}

output "public_subnet_ids" {
  value = values(aws_subnet.public_subnets)[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}