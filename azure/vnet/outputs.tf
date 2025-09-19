output "vnet_id" {
  description = "ID of the virtual network"
  value       = (var.use_existing_vnet ? data.azurerm_virtual_network.vnet[0].id : azurerm_virtual_network.vnet[0].id)
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = (var.use_existing_vnet ? data.azurerm_virtual_network.vnet[0].name : azurerm_virtual_network.vnet[0].name)
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = (var.use_existing_vnet ? data.azurerm_virtual_network.vnet[0].address_space : azurerm_virtual_network.vnet[0].address_space)
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
