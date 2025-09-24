output "tls_enabled" {
  value = var.create
}

output "certificate_secret_id" {
  value = var.create ? azurerm_key_vault_certificate.cert[0].secret_id : null
}

output "certificate_thumbprint" {
  value = var.create ? azurerm_key_vault_certificate.cert[0].thumbprint : null
}