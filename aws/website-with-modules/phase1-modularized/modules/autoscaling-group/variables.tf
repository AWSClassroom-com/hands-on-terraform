variable "account" {
  type = string
}

variable "image_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "instance_count_min" {
  type = number
}

variable "instance_count_max" {
  type = number
}

variable "user_data_base64" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type = string
}