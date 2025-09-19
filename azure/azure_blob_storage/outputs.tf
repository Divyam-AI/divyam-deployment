output "router_logs_storage_account_id" {
  description = "The ID of the Azure Storage Account."
  value       = azurerm_storage_account.divyam_router_logs.id
}

output "router_logs_storage_account_name" {
  description = "The name of the Azure Storage Account."
  value       = azurerm_storage_account.divyam_router_logs.name
}

output "router_logs_container_names" {
  description = "A list of the names of the created storage containers."
  value       = values(azurerm_storage_container.container)[*].name
}

output "router_logs_container_ids" {
  description = "A map of the names of the containers to their resource IDs."
  value       = { for k, v in azurerm_storage_container.container : k => v.id }
}

output "router_logs_storage_account_connection_string" {
  value     = azurerm_storage_account.divyam_router_logs.primary_connection_string
  sensitive = true
}
