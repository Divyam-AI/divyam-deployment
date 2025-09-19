output "azure_key_vault_id" {
  description = "The ID of the Azure Key Vault"
  value       = azurerm_key_vault.divyam.id
}

output "azure_key_vault_name" {
  description = "The name of the Azure Key Vault"
  value       = azurerm_key_vault.divyam.name
}

output "azure_key_vault_uri" {
  description = "The URI of the Azure Key Vault (used to access secrets)"
  value       = azurerm_key_vault.divyam.vault_uri
}

output "azure_key_vault_resource_group" {
  description = "The resource group in which the Key Vault is created"
  value       = azurerm_key_vault.divyam.resource_group_name
}
