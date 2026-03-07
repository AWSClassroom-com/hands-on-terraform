variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_name" {
  type        = string
  description = "VPC name (for tags)"
}

variable "subnets" {
  type        = map(string)
  description = "Map of { az => cidr }"
}

variable "map_public_ip" {
  type        = bool
  description = "Whether subnets get public IPs"
}

variable "route_table_name" {
  type        = string
  default     = null
  description = "Optional RT name tag"
}

variable "route_target_type" {
  type        = string
  description = "\"igw\" or \"nat\""
  validation {
    condition     = contains(["igw", "nat"], var.route_target_type)
    error_message = "route_target_type must be one of: igw, nat"
  }
}

variable "route_target_id" {
  type        = string
  description = "Gateway ID for the route"
}

variable "subnet_name_prefix" {
  type        = string
  description = "Prefix for subnet name tags"
}

variable "subnet_name_by_az" {
  type        = map(string)
  default     = {}
  description = "Optional per-AZ name overrides"
}