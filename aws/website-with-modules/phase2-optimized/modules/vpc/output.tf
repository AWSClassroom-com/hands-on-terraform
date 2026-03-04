output "vpc_id" {
  value = aws_vpc.custom-vpc.id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id
}

output "ngw_id" {
  value = aws_nat_gateway.ngw.id
}