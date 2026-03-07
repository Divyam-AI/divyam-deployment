# Merged view of all storage accounts (created + looked up) for outputs
locals {
  all_storage_account_ids   = merge(
    { for k, v in azurerm_storage_account.this : k => v.id },
    { for k, v in data.azurerm_storage_account.existing : k => v.id }
  )
  all_storage_account_names = merge(
    { for k, v in azurerm_storage_account.this : k => v.name },
    { for k, v in data.azurerm_storage_account.existing : k => v.name }
  )
  all_storage_account_connection_strings = merge(
    { for k, v in azurerm_storage_account.this : k => v.primary_connection_string },
    { for k, v in data.azurerm_storage_account.existing : k => v.primary_connection_string }
  )
  all_container_ids = merge(
    { for k, v in azurerm_storage_container.container : k => v.id },
    { for k, v in data.azurerm_storage_container.existing : k => v.id }
  )
}

output "storage_account_ids" {
  description = "Map of storage account key to Azure resource ID."
  value       = local.all_storage_account_ids
}

output "storage_account_names" {
  description = "Map of storage account key to Azure storage account name."
  value       = local.all_storage_account_names
}

output "container_names" {
  description = "List of all storage container names (created + looked up)."
  value       = concat(
    [for v in azurerm_storage_container.container : v.name],
    [for v in data.azurerm_storage_container.existing : v.name]
  )
}

output "container_ids" {
  description = "Map of container key (account_key/container_name) to Azure resource ID."
  value       = local.all_container_ids
}

output "storage_account_connection_strings" {
  description = "Map of storage account key to primary connection string."
  value       = local.all_storage_account_connection_strings
  sensitive   = true
}

# Backward compatibility: storage identified by type "router-requests-logs" in divyam_object_storages (router_requests_logs_storage_key).
output "router_requests_logs_storage_account_id" {
  description = "ID of the storage account with type 'router-requests-logs' (from divyam_object_storages)."
  value       = var.router_requests_logs_storage_key != null ? try(local.all_storage_account_ids[var.router_requests_logs_storage_key], null) : null
}

output "router_requests_logs_storage_account_name" {
  description = "Name of the storage account with type 'router-requests-logs' (from divyam_object_storages)."
  value       = var.router_requests_logs_storage_key != null ? try(local.all_storage_account_names[var.router_requests_logs_storage_key], null) : null
}

output "router_requests_logs_storage_account_connection_string" {
  description = "Primary connection string for the storage account with type 'router-requests-logs' (from divyam_object_storages)."
  value       = var.router_requests_logs_storage_key != null ? try(local.all_storage_account_connection_strings[var.router_requests_logs_storage_key], null) : null
  sensitive   = true
}

output "router_requests_logs_container_names" {
  description = "Container names for the storage account with type 'router-requests-logs' (from divyam_object_storages)."
  value       = var.router_requests_logs_storage_key != null ? [for k, v in merge(azurerm_storage_container.container, data.azurerm_storage_container.existing) : v.name if startswith(k, "${var.router_requests_logs_storage_key}/")] : []
}
