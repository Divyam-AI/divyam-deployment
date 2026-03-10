# Azure VNet — single subnet, single app_gw_subnet (source of truth: values/defaults.hcl).

locals {
  vnet_name = var.vnet.create ? azurerm_virtual_network.vnet[0].name : data.azurerm_virtual_network.vnet[0].name
  # Per-resource tags so the VNet gets its name in tags (e.g. #{resource_name}).
  tag_context_base   = merge(var.tag_globals, var.tag_context)
  rendered_tags_vnet = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = var.vnet.name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "azurerm_virtual_network" "vnet" {
  count               = var.vnet.create ? 1 : 0
  name                = var.vnet.name
  address_space       = var.vnet.address_space
  location            = var.vnet.region
  resource_group_name = var.vnet.scope_name

  tags = local.rendered_tags_vnet

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

# --- Azure VNet peering (hub-and-spoke: peer this VNet to remote VNets) ---
# When shared_vpc_host = true, create peering from this VNet to each remote VNet in service_project_ids.
# Remote VNet IDs must be full ARM IDs. Reverse peering (remote → this VNet) must be created elsewhere.
resource "azurerm_virtual_network_peering" "hub_to_remote" {
  for_each = (var.vnet.create) && try(var.vnet.shared_vpc_host, false) ? toset(try(var.vnet.service_project_ids, [])) : toset([])

  name                         = "peer-${substr(md5(each.key), 0, 12)}"
  resource_group_name          = var.vnet.scope_name
  virtual_network_name         = local.vnet_name
  remote_virtual_network_id    = each.key
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
}
