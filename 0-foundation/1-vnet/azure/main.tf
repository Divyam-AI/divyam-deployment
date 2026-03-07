# Azure VNet — single subnet, single app_gw_subnet (source of truth: values/defaults.hcl).

locals {
  vnet_name = var.vnet.create ? azurerm_virtual_network.vnet[0].name : data.azurerm_virtual_network.vnet[0].name
}

resource "azurerm_virtual_network" "vnet" {
  count               = var.vnet.create ? 1 : 0
  name                = var.vnet.name
  address_space       = var.vnet.address_space
  location            = var.vnet.region
  resource_group_name = var.vnet.scope_name

  tags = local.rendered_tags

  lifecycle {
    ignore_changes  = [name]
    prevent_destroy = true
  }
}

data "azurerm_virtual_network" "vnet" {
  count               = var.vnet.create ? 0 : 1
  name                = var.vnet.name
  resource_group_name = var.vnet.scope_name
}

# Subnet: create or lookup
resource "azurerm_subnet" "subnet" {
  count = var.vnet.subnet.create ? 1 : 0

  name                 = var.vnet.subnet.name
  resource_group_name  = var.vnet.scope_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.vnet.subnet.subnet_ip]
  service_endpoints    = ["Microsoft.Storage"]

  lifecycle {
    ignore_changes  = [name]
    prevent_destroy = true
  }
}

data "azurerm_subnet" "subnet" {
  count = var.vnet.subnet.create ? 0 : 1

  name                 = var.vnet.subnet.name
  virtual_network_name = local.vnet_name
  resource_group_name  = var.vnet.scope_name
}

# App Gateway subnet: create or lookup
resource "azurerm_subnet" "app_gw_subnet" {
  count = var.vnet.app_gw_subnet.create ? 1 : 0

  name                 = var.vnet.app_gw_subnet.name
  resource_group_name  = var.vnet.scope_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.vnet.app_gw_subnet.subnet_ip]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "application_gateway_delegation"
    service_delegation {
      name = "Microsoft.Network/applicationGateways"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  lifecycle {
    ignore_changes  = [name]
    prevent_destroy = true
  }
}

data "azurerm_subnet" "app_gw_subnet" {
  count = var.vnet.app_gw_subnet.create ? 0 : 1

  name                 = var.vnet.app_gw_subnet.name
  virtual_network_name = local.vnet_name
  resource_group_name  = var.vnet.scope_name
}
