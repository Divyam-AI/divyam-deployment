output "registered_providers" {
  description = "List of registered Azure Resource Provider namespaces"
  value       = var.enabled ? keys(azurerm_resource_provider_registration.providers) : []
}
