# Azure Database for MySQL Flexible Server. Config from values/defaults.hcl cloudsql.
# VNet fetched by name via Azure API (no dependency on 0-foundation). Per-resource tags with resource name.

# Look up existing VNet by name (from values/defaults.hcl). Only when create or force for import.
data "azurerm_virtual_network" "vnet" {
  count = var.create ? 1 : 0

  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

locals {
  tag_context_base         = merge(var.tag_globals, var.tag_context)
  rendered_tags_mysql_srv  = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.server_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

# Delegated subnet for MySQL Flexible Server (must be in the VNet).
resource "azurerm_subnet" "mysql" {
  count = var.create ? 1 : 0

  name                 = "${var.server_name}-mysql-snet"
  resource_group_name  = var.vnet_resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.mysql_subnet_prefix]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Private DNS zone for MySQL (required for private access).
resource "azurerm_private_dns_zone" "mysql" {
  count = var.create ? 1 : 0

  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  count = var.create ? 1 : 0

  name                  = "${var.server_name}-mysql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql[0].name
  virtual_network_id    = data.azurerm_virtual_network.vnet[0].id
}

# MySQL Flexible Server with private access.
resource "azurerm_mysql_flexible_server" "default" {
  count = var.create ? 1 : 0

  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  delegated_subnet_id = azurerm_subnet.mysql[0].id
  private_dns_zone_id = azurerm_private_dns_zone.mysql[0].id

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  sku_name   = "GP_Standard_D2ds_v4"
  version    = "8.0.21"

  storage {
    size_gb = 20
  }

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = local.rendered_tags_mysql_srv

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_mysql_flexible_database" "default" {
  count = var.create ? 1 : 0

  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.default[0].name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}
