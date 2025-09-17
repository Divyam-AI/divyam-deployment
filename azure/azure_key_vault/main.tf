data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "divyam" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # TODO: Figure this config.
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}

resource "azurerm_key_vault_access_policy" "divyam" {
  key_vault_id = azurerm_key_vault.divyam.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "Set",
    "List",
    "Recover"
  ]

  key_permissions = [
    "Get",
    "Create",
    "Update",
    "List",
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Import",
    "Create",
    "Delete",
    "Update"
  ]
}
