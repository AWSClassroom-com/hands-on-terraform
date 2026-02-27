variable "region" {
  type    = string
  default = "us-east-2"
}
variable "vpc_name" {
  type        = string
  description = "Name of the VPC for the application"
}
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}
variable "public_subnet_a_name" {
  type        = string
  description = "Name of the public subnet A"
}
variable "public_subnet_a_cidr" {
  type        = string
  description = "CIDR block for the public subnet A"
}
variable "route_table_name" {
  type        = string
  description = "Name of the route table for the VPC"
}