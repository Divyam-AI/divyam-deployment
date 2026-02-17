variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "divyam_router_logs_storage_account_name" {
  description = "Name of the storage account for router logs"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "storage_account_ip_rules" {
  type        = list(string)
  default     = []
  description = "List of public IP or CIDR addresses to allow access from."
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs to allow for storage"
  type        = map(string)
}

variable "divyam_router_logs_storage_container_names" {
  description = "Names of the storage containers for router logs"
  type        = list(string)
  default     = []
}
