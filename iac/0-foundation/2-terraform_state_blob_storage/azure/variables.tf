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

variable "local_state" {
  description = "When true, do not create or lookup storage; state is stored locally only."
  type        = bool
  default     = false
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
  description = "Map of subnet name to resource ID to allow for storage. If empty and vnet_name is set, subnets are looked up from the vnet."
  type        = map(string)
  default     = {}
}

variable "vnet_name" {
  description = "When subnet_ids is empty, look up this vnet's subnets for network_rules. Leave empty to use only subnet_ids."
  type        = string
  default     = ""
}

variable "vnet_resource_group_name" {
  description = "Resource group containing vnet_name when doing vnet subnet lookup."
  type        = string
  default     = ""
}

