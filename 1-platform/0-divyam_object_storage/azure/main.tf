locals {
  to_create = { for k, v in var.storage_accounts : k => v if try(v.create, true) }
  to_lookup  = { for k, v in var.storage_accounts : k => v if !try(v.create, true) }

  # Subnet IDs: look up in Azure by vnet name + subnet names from config (vnet.subnets[].subnet_name). When subnet_names is empty, no network rules.
  subnet_ids = length(var.vnet_subnet_names) > 0 ? { for name in var.vnet_subnet_names : name => data.azurerm_subnet.vnet_subnets[name].id } : {}

  # Flat set of containers for accounts we create: "account_key/container_name" -> { account_key, container_name }
  containers_flat_created = length(local.to_create) > 0 ? merge([
    for acc_key, acc in local.to_create : {
      for c in acc.container_names : "${acc_key}/${c}" => { account_key = acc_key, container_name = c }
    }
  ]...) : {}

  # Flat set of containers for accounts we look up (for data source)
  containers_flat_lookup = length(local.to_lookup) > 0 ? merge([
    for acc_key, acc in local.to_lookup : {
      for c in acc.container_names : "${acc_key}/${c}" => { account_key = acc_key, container_name = c }
    }
  ]...) : {}

  # Per-resource tags so each storage account gets its actual name in tags (not a generic one).
  rendered_tags_for = {
    for k, v in local.to_create : k => {
      for tag_k, tag_v in var.common_tags : tag_k => replace(tag_v, "/#\\{([^}]+)\\}/", (lookup(merge(local.tag_context, { resource_name = v.name }), try(regex("#\\{([^}]+)\\}", tag_v)[0], ""), "")))
    }
  }
}

# Look up vnet and subnets in Azure by name (from defaults.hcl vnet -> subnets -> subnet_name). VNet must exist (e.g. 0-foundation/1-vnet applied or pre-created).
data "azurerm_virtual_network" "vnet" {
  count               = length(var.vnet_subnet_names) > 0 ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "vnet_subnets" {
  for_each             = length(var.vnet_subnet_names) > 0 ? toset(var.vnet_subnet_names) : toset([])
  name                 = each.key
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

# --- Create path ---
resource "azurerm_storage_account" "this" {
  for_each             = local.to_create
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  location             = var.location
  account_tier         = var.account_tier
  account_replication_type = var.account_replication_type

  network_rules {
    default_action             = "Deny"
    ip_rules                   = var.storage_account_ip_rules
    virtual_network_subnet_ids = values(local.subnet_ids)
  }

  tags = local.rendered_tags_for[each.key]

  lifecycle {
    ignore_changes = [
      name
    ]
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "container" {
  for_each           = local.containers_flat_created
  name               = each.value.container_name
  storage_account_id = azurerm_storage_account.this[each.value.account_key].id
  container_access_type = "private"
}

# --- Lookup path (create = false): fetch existing account and containers from Azure ---
data "azurerm_storage_account" "existing" {
  for_each             = local.to_lookup
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
}

data "azurerm_storage_container" "existing" {
  for_each             = local.containers_flat_lookup
  name                 = each.value.container_name
  storage_account_id  = data.azurerm_storage_account.existing[each.value.account_key].id
}
