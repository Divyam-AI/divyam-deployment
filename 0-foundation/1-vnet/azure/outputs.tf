output "vnet_id" {
  description = "ID of the virtual network"
  value       = (var.vnet.create ? azurerm_virtual_network.vnet[0].id : data.azurerm_virtual_network.vnet[0].id)
}

# Ensures Terragrunt sees at least one output when this module is applied (avoids "dependency has no outputs" warning).
output "applied" {
  description = "True when module has been applied; ensures dependency always has at least one output for Terragrunt."
  value       = true
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = (var.vnet.create ? azurerm_virtual_network.vnet[0].name : data.azurerm_virtual_network.vnet[0].name)
}

output "vnet_resource_group_name" {
  description = "Vnet resource group"
  value       = var.vnet.scope_name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = (var.vnet.create ? azurerm_virtual_network.vnet[0].address_space : data.azurerm_virtual_network.vnet[0].address_space)
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = merge({
    for name, subnet in azurerm_subnet.subnets : name => subnet.id
    },
    {
      for name, subnet in data.azurerm_subnet.existing_subnets : name => subnet.id
    }
  )
}

output "subnet_names" {
  description = "List of subnet names"
  value = concat([
    for subnet in azurerm_subnet.subnets : subnet.name
    ],
    [
      for subnet in data.azurerm_subnet.existing_subnets : subnet.name
    ]
  )
}

output "subnet_prefixes" {
  description = "Map of subnet names to their address prefixes"
  value = merge({
    for name, subnet in azurerm_subnet.subnets : name =>
    subnet.address_prefixes[0]
    },
    {
      for name, subnet in data.azurerm_subnet.existing_subnets : name =>
      subnet.address_prefixes[0]
    }
  )
}

# App Gateway subnet outputs (created + existing)
output "app_gw_subnet_ids" {
  description = "Map of App Gateway subnet names to their IDs"
  value = merge({
    for name, subnet in azurerm_subnet.app_gw_subnets : name => subnet.id
    },
    {
      for name, subnet in data.azurerm_subnet.existing_app_gw_subnets : name => subnet.id
    }
  )
}

output "app_gw_subnet_names" {
  description = "List of App Gateway subnet names"
  value = concat([
    for subnet in azurerm_subnet.app_gw_subnets : subnet.name
    ],
    [
      for subnet in data.azurerm_subnet.existing_app_gw_subnets : subnet.name
    ]
  )
}

output "app_gw_subnet_prefixes" {
  description = "Map of App Gateway subnet names to their address prefixes"
  value = merge({
    for name, subnet in azurerm_subnet.app_gw_subnets : name => subnet.address_prefixes[0]
    },
    {
      for name, subnet in data.azurerm_subnet.existing_app_gw_subnets : name => subnet.address_prefixes[0]
    }
  )
}
