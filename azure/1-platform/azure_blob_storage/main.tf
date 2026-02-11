locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

resource "azurerm_storage_account" "divyam_router_logs" {
  name                = var.divyam_router_logs_storage_account_name
  resource_group_name = var.resource_group_name

  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  network_rules {
    default_action             = "Deny"
    ip_rules                   = var.storage_account_ip_rules
    virtual_network_subnet_ids = values(var.subnet_ids)
  }

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.divyam_router_logs_storage_account_name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }

  lifecycle {
    ignore_changes = [
      name
    ]
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "container" {
  for_each              = toset(var.divyam_router_logs_storage_container_names)
  name                  = each.value
  storage_account_id    = azurerm_storage_account.divyam_router_logs.id
  container_access_type = "private"
}
