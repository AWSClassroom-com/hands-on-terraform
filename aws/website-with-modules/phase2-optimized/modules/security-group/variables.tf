variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ingress_rules" {
  type = map(object({
    from_port                    = number
    to_port                      = number
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
}

variable "egress_rules" {
  type = map(object({
    ip_protocol = string
    cidr_ipv4   = optional(string)
  }))
}