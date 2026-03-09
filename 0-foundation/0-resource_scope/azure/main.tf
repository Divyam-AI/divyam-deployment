# Create resource group when create = true
locals {
  tag_context_base = merge(var.tag_globals, var.tag_context)
  rendered_tags_rg = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.resource_scope.name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "azurerm_resource_group" "rd" {
  count    = var.resource_scope.create ? 1 : 0
  name     = var.resource_scope.name
  location = var.region

  tags = local.rendered_tags_rg  # Per-resource tags with resource name

  lifecycle {
    prevent_destroy = true
  }
}

# Look up existing resource group when create = false
data "azurerm_resource_group" "rd" {
  count = var.resource_scope.create ? 0 : 1
  name  = var.resource_scope.name
}

locals {
  rg = var.resource_scope.create ? azurerm_resource_group.rd[0] : data.azurerm_resource_group.rd[0]
}