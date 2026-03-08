variable "create" {
  description = "When true, create Azure MySQL Flexible Server and supporting resources."
  type        = bool
  default     = false
}

variable "resource_group_name" {
  description = "Resource group for the MySQL server and delegated subnet."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network (from defaults.hcl vnet.name)."
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Resource group containing the VNet (from defaults.hcl vnet.scope_name)."
  type        = string
}

variable "server_name" {
  description = "Name of the MySQL Flexible Server (from cloudsql.instance_name)."
  type        = string
}

variable "administrator_login" {
  description = "MySQL admin username."
  type        = string
}

variable "administrator_password" {
  description = "MySQL admin password. Use TF_VAR_administrator_password or TF_VAR_divyam_db_password."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Initial database to create."
  type        = string
  default     = "divyam"
}

# MySQL delegated subnet: use a dedicated CIDR (e.g. 10.0.2.0/24). Must not overlap existing subnets.
variable "mysql_subnet_prefix" {
  description = "Address prefix for the MySQL delegated subnet."
  type        = string
  default     = "10.0.2.0/24"
}
