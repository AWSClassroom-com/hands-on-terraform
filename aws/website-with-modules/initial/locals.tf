data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Create a map of AZ Name -> CIDR for Public Subnets
  public_subnets = {
    for i, az in data.aws_availability_zones.available.names : 
    az => cidrsubnet(var.vpc_cidr, 4, i)
  }
}