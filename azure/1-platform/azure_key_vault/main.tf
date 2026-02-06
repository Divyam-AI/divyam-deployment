locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "divyam" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.key_vault_name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }

  # TODO: Figure this config.
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  # Prevent terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_access_policy" "divyam" {
  key_vault_id = azurerm_key_vault.divyam.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "Set",
    "List",
    "Recover",
    "Delete"
  ]

  key_permissions = [
    "Get",
    "Create",
    "Update",
    "List",
    "Delete"
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
