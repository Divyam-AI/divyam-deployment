resource "azurerm_storage_account" "terraform" {
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

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "container" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.terraform.id
  container_access_type = "private"
}