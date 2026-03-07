variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

# Map of storage account key (logical name) -> { name = full Azure storage account name, container_names = [...] }.
# Caller is responsible for building the full name (e.g. replace(deployment_prefix, "-", "") + suffix).
variable "storage_accounts" {
  description = "Map of storage account key to { name = full Azure name, container_names = list, create = bool, type = optional string }. create = false uses data sources to fetch existing. type identifies usage (e.g. router-requests-logs) for typed outputs."
  type = map(object({
    name            = string
    container_names = list(string)
    create          = optional(bool, true)
    type            = optional(string) # e.g. "router-requests-logs"
  }))
  default = {}
}

variable "router_requests_logs_storage_key" {
  description = "Key in storage_accounts that holds the router-requests-logs storage (set from config type). Used for router_requests_logs_* outputs."
  type        = string
  default     = null
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
