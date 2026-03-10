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
variable "route_table_name" {
  type        = string
  description = "Name of the route table for the VPC"
}
variable "security_group_name" {
  type        = string
  description = "Name of the security group for the Web Servers"
}
variable "account" {
  description = "Your IAM user account name used to log in to AWS (for example, user01 or user21). Used to prefix resource names."
  type        = string
}
variable "image_id" {
  description = "The id of the machine image (AMI) to use for the server."
  type        = map(string)
  default = {
    us-east-1 = "ami-0532be01f26a3de55",
    us-east-2 = "ami-03ea746da1a2e36e7"
  }
}
variable "instance_type" {
  description = "The size of the VM instances."
  type        = string
  default     = "t3.micro"
}
variable "instance_count_min" {
  description = "Number of instances to provision."
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count_min > 0 && var.instance_count_min <= 3
    error_message = "Instance count min must be between 1 and 3."
  }
}
variable "instance_count_max" {
  description = "Number of instances to provision."
  type        = number
  default     = 2
  validation {
    condition     = var.instance_count_max >= 3 && var.instance_count_max <= 4
    error_message = "Instance count max must be between 3 and 4."
  }
}