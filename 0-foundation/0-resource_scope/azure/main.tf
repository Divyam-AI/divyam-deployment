# Defaults from cloud when region is empty (only when creating a resource group).
# Current subscription/tenant from provider; region defaults to southindia when not set.
data "azurerm_client_config" "current" {}

locals {
  # When creating and region is empty, use fallback (Azure has no single "default region" per subscription).
  default_region = var.region != "" ? var.region : "southindia"
}

# Create resource group when create = true
locals {
  tag_context_base = merge(var.tag_globals, var.tag_context)
  rendered_tags_rg = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.resource_scope.name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "azurerm_resource_group" "rd" {
  count    = var.resource_scope.create || var.import_mode ? 1 : 0
  name     = var.resource_scope.name
  location = local.default_region

  tags = local.rendered_tags_rg  # Per-resource tags with resource name

  lifecycle {
    prevent_destroy = true
    ignore_changes   = [name, location]  # Immutable; do not change if resource group already exists
  }
}

# Look up existing resource group when create = false and not forcing for import
data "azurerm_resource_group" "rd" {
  count = var.resource_scope.create || var.import_mode ? 0 : 1
  name  = var.resource_scope.name
}

locals {
  rg = var.resource_scope.create || var.import_mode ? azurerm_resource_group.rd[0] : data.azurerm_resource_group.rd[0]
}