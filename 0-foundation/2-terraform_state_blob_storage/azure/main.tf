# Look up the existing Azure Storage Account when create = false and not forcing for import.
data "azurerm_storage_account" "terraform" {
  count               = (var.create || var.local_state) ? 0 : 1
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

# When subnet_ids is empty and vnet_name is set, resolve subnets from the vnet for network_rules.
data "azurerm_virtual_network" "vnet" {
  count               = (var.create && !var.local_state) && length(var.subnet_ids) == 0 && var.vnet_name != "" ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "vnet_subnets" {
  for_each = (var.create && !var.local_state) && length(var.subnet_ids) == 0 && var.vnet_name != "" ? toset(coalesce(data.azurerm_virtual_network.vnet[0].subnets, [])) : toset([])
  name                 = each.key
  virtual_network_name  = data.azurerm_virtual_network.vnet[0].name
  resource_group_name   = data.azurerm_virtual_network.vnet[0].resource_group_name
}

locals {
  # Use provided subnet_ids, or when empty and vnet lookup is configured, build map from vnet subnets.
  resolved_subnet_ids = (var.local_state ? {} : (length(var.subnet_ids) > 0 ? var.subnet_ids : (
    length(data.azurerm_subnet.vnet_subnets) > 0 ? { for k, s in data.azurerm_subnet.vnet_subnets : k => s.id } : {}
  )))
  tag_context_base = merge(var.tag_globals, var.tag_context)
  rendered_tags_storage_account = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.storage_account_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "azurerm_storage_account" "terraform" {
  count               = (var.create && !var.local_state) ? 1 : 0
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name

  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  network_rules {
    default_action             = "Deny"
    ip_rules                   = var.storage_account_ip_rules
    virtual_network_subnet_ids = length(local.resolved_subnet_ids) > 0 ? values(local.resolved_subnet_ids) : []
  }

  tags = local.rendered_tags_storage_account

  lifecycle {
    prevent_destroy = true
  }
}

# Look up the existing Azure Storage Container when create = false and not forcing for import.
data "azurerm_storage_container" "container" {
  count              = (var.create || var.local_state) ? 0 : 1
  name               = var.storage_container_name
  storage_account_id = data.azurerm_storage_account.terraform[0].id
}

resource "azurerm_storage_container" "container" {
  count                 = (var.create && !var.local_state) ? 1 : 0
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.terraform[0].id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}