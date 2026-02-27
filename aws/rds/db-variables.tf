variable "db_subnet_a_name" {
  type        = string
  description = "Name of DB subnet A"
}
variable "db_subnet_a_cidr" {
  type        = string
  description = "CIDR block for DB subnet A"
}
variable "db_subnet_b_name" {
  type        = string
  description = "Name of DB subnet B"
}
variable "db_subnet_b_cidr" {
  type        = string
  description = "CIDR block for DB subnet B"
}
variable "db_private_route_table_name" {
  type        = string
  description = "Name of the private route table for DB subnets"
}
variable "db_subnet_group_name" {
  type        = string
  description = "Name of the RDS subnet group"
}
variable "rds_security_group_name" {
  type        = string
  description = "Name of the RDS security group"
}
variable "db_identifier" {
  type        = string
  description = "Identifier for the RDS instance"
}
variable "db_username" {
  type        = string
  description = "Master username for the database"
  default     = "postgres"
}
variable "db_name" {
  type        = string
  description = "Initial database name"
  default     = "appdb"
}
variable "db_engine_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = "17.3"
}
variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}
variable "db_allocated_storage" {
  type        = number
  description = "Allocated storage in GiB"
  default     = 20
}
