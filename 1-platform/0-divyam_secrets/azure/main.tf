# Divyam secrets: uses common module for secrets map, creates Azure Key Vault (optional) and Key Vault secrets.
# Tags use root-generated local.rendered_tags; per-resource names so each resource gets its actual name in tags.
# common module block is in generated common_module.tf (path set by Terragrunt so it works in cache).

data "azurerm_client_config" "current" {}

# Per-resource tags: key vault and each secret get their actual name in tags.
locals {
  rendered_tags_for_key_vault = {
    for tag_k, tag_v in var.common_tags : tag_k => replace(tag_v, "/#\\{([^}]+)\\}/", (lookup(merge(local.tag_context, { resource_name = var.key_vault_name }), try(regex("#\\{([^}]+)\\}", tag_v)[0], ""), "")))
  }
  rendered_tags_for_secrets = var.create_secrets ? {
    for name in toset(module.common.secret_names) : name => {
      for tag_k, tag_v in var.common_tags : tag_k => replace(tag_v, "/#\\{([^}]+)\\}/", (lookup(merge(local.tag_context, { resource_name = name }), try(regex("#\\{([^}]+)\\}", tag_v)[0], ""), "")))
    }
  } : {}
}

# Look up existing Key Vault by name when create_vault is false and key_vault_id is not provided and not forcing for import.
data "azurerm_key_vault" "existing" {
  count               = (!var.create_vault && var.key_vault_id == null && var.key_vault_name != null) ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_key_vault" "this" {
  count = (var.create_vault && var.key_vault_id == null) ? 1 : 0

  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7

  tags = local.rendered_tags_for_key_vault

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_access_policy" "current" {
  count = (var.create_vault && var.key_vault_id == null) ? 1 : 0

  key_vault_id = azurerm_key_vault.this[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "Set", "List", "Recover", "Delete"]
  key_permissions    = ["Get", "Create", "Update", "List", "Delete"]
  certificate_permissions = ["Get", "List", "Import", "Create", "Delete", "Update"]
}

locals {
  key_vault_id = coalesce(
    var.key_vault_id,
    try(azurerm_key_vault.this[0].id, null),
    try(data.azurerm_key_vault.existing[0].id, null)
  )
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each     = var.create_secrets ? toset(module.common.secret_names) : toset([])
  name         = each.key
  value        = module.common.secrets[each.key]
  key_vault_id = local.key_vault_id

  tags = local.rendered_tags_for_secrets[each.key]

  # Re-running with new values updates existing secrets (new version in Key Vault).
  lifecycle {
    prevent_destroy = true
  }
}
