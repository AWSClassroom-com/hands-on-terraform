variable "region" {
  type    = string
  default = "us-east-2"
}

variable "account" {
  type        = string
  description = "Your IAM user account name used to log in to AWS (for example, user01 or user21). Used to prefix resource names."
}