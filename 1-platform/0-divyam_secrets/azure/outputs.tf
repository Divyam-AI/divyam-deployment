output "key_vault_id" {
  description = "Azure Key Vault resource ID (created, looked up, or passed in)."
  value       = local.key_vault_id
}

output "key_vault_name" {
  description = "Key Vault name."
  value = coalesce(
    try(azurerm_key_vault.this[0].name, null),
    try(data.azurerm_key_vault.existing[0].name, null),
    var.key_vault_name
  )
}

output "secret_names" {
  description = "List of secret names stored in Key Vault."
  value       = [for k in azurerm_key_vault_secret.secrets : k.name]
}
