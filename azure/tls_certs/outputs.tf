output "tls_enabled" {
  value = azurerm_key_vault_certificate.cert[0].secret_id != null
}

output "certificate_secret_id" {
  value = azurerm_key_vault_certificate.cert[0].secret_id
}

output "certificate_thumbprint" {
  value = azurerm_key_vault_certificate.cert[0].thumbprint
}
