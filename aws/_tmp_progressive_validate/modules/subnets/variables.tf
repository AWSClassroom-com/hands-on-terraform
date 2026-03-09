variable "vpc_id" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "subnets" {
  type = map(string)
}

variable "map_public_ip" {
  type = bool
}

variable "route_table_name" {
  type    = string
  default = null
}

variable "route_target_type" {
  type = string
  validation {
    condition     = contains(["igw", "nat"], var.route_target_type)
    error_message = "route_target_type must be one of: igw, nat"
  }
}

variable "route_target_id" {
  type = string
}

variable "subnet_name_prefix" {
  type = string
}

variable "subnet_name_by_az" {
  type    = map(string)
  default = {}
}