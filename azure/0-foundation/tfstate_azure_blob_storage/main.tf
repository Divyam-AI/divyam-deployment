locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

# Look up the existing Azure Storage Account.
data "azurerm_storage_account" "terraform" {
  count               = var.create ? 0 : 1
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_storage_account" "terraform" {
  count               = var.create ? 1 : 0
  name                = var.storage_account_name
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
      resource_name  = var.storage_account_name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Look up the existing Azure Storage Container..
data "azurerm_storage_container" "container" {
  count              = var.create ? 0 : 1
  name               = var.storage_container_name
  storage_account_id = data.azurerm_storage_account.terraform[0].id
}

resource "azurerm_storage_container" "container" {
  count                 = var.create ? 1 : 0
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.terraform[0].id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}