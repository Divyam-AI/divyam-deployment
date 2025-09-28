locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }

  filtered_subnets_to_create = [
    # Filter out subnets to create.
    for subnet in var.subnets : { subnet_name = subnet.subnet_name, subnet = subnet } if !subnet.use_existing
  ]

  # Convert the filtered list of pairs back into a map
  subnets_to_create = { for pair in local.filtered_subnets_to_create : pair.subnet_name => pair.subnet }

  filtered_subnets_existing = [
    # Filter out subnets to create.
    for subnet in var.subnets : { subnet_name = subnet.subnet_name, subnet = subnet } if subnet.use_existing
  ]

  # Convert the filtered list of pairs back into a map
  subnets_existing = { for pair in local.filtered_subnets_existing : pair.subnet_name => pair.subnet }
}

resource "azurerm_virtual_network" "vnet" {
  count               = var.use_existing_vnet ? 0 : 1
  name                = var.network_name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.vnet_resource_group_name != null ? var.vnet_resource_group_name : var.resource_group_name

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.network_name
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

# Look up the existing Azure Virtual Network.
data "azurerm_virtual_network" "vnet" {
  count               = var.use_existing_vnet ? 1 : 0
  name                = var.network_name
  resource_group_name = var.vnet_resource_group_name != null ? var.vnet_resource_group_name : var.resource_group_name
}

# Look up existing subnets
data "azurerm_subnet" "existing_subnets" {
  for_each             = local.subnets_existing
  name                 = each.key
  virtual_network_name = (var.use_existing_vnet ? data.azurerm_virtual_network.vnet[0].name : azurerm_virtual_network.vnet[0].name)
  resource_group_name  = var.vnet_resource_group_name != null ? var.vnet_resource_group_name : var.resource_group_name
}

resource "azurerm_subnet" "subnets" {
  for_each = local.subnets_to_create

  name                 = each.key
  resource_group_name  = var.vnet_resource_group_name != null ? var.vnet_resource_group_name : var.resource_group_name
  virtual_network_name = (var.use_existing_vnet ? data.azurerm_virtual_network.vnet[0].name : azurerm_virtual_network.vnet[0].name)
  address_prefixes     = [each.value.subnet_ip]
  service_endpoints    = ["Microsoft.Storage"]

  lifecycle {
    ignore_changes = [
      name
    ]
    prevent_destroy = true
  }
}
