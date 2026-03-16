# Register Azure Resource Providers (equivalent to az provider register).
# Required for Terraform to create resources; run early in foundation.
# Uses azurerm_resource_provider_registration so registration is managed in Terraform.
resource "azurerm_resource_provider_registration" "providers" {
  for_each = var.enabled ? toset(var.provider_namespaces) : toset([])

  name = each.key
}
