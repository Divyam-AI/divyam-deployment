variable "resource_group_name" {
  description = "Name of the resource group for the storage account"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "create" {
  description = "Whether to create the storage account and container (false = use existing)"
  type        = bool
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account for Terraform state"
  type        = string
}

variable "storage_container_name" {
  description = "Name of the blob container for Terraform state"
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
