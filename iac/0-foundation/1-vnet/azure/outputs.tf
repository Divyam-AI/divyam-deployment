output "vnet_id" {
  description = "ID of the virtual network"
  value       = var.vnet.create ? azurerm_virtual_network.vnet[0].id : data.azurerm_virtual_network.vnet[0].id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = var.vnet.create ? azurerm_virtual_network.vnet[0].name : data.azurerm_virtual_network.vnet[0].name
}

output "vnet_resource_group_name" {
  description = "VNet resource group"
  value       = var.vnet.scope_name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = var.vnet.create ? azurerm_virtual_network.vnet[0].address_space : data.azurerm_virtual_network.vnet[0].address_space
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = var.vnet.subnet.create ? azurerm_subnet.subnet[0].id : data.azurerm_subnet.subnet[0].id
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = var.vnet.subnet.name
}

output "subnet_prefix" {
  description = "Address prefix of the subnet"
  value       = var.vnet.subnet.create ? azurerm_subnet.subnet[0].address_prefixes[0] : data.azurerm_subnet.subnet[0].address_prefixes[0]
}

output "app_gw_subnet_id" {
  description = "ID of the App Gateway subnet"
  value       = var.vnet.app_gw_subnet.create ? azurerm_subnet.app_gw_subnet[0].id : data.azurerm_subnet.app_gw_subnet[0].id
}

# Map of subnet keys to IDs for modules that expect dependency.vnet.outputs.subnet_ids (e.g. 2-terraform_state_blob_storage).
output "subnet_ids" {
  description = "Map of subnet logical names to subnet resource IDs"
  value = {
    subnet        = var.vnet.subnet.create ? azurerm_subnet.subnet[0].id : data.azurerm_subnet.subnet[0].id
    app_gw_subnet = var.vnet.app_gw_subnet.create ? azurerm_subnet.app_gw_subnet[0].id : data.azurerm_subnet.app_gw_subnet[0].id
  }
}

output "app_gw_subnet_name" {
  description = "Name of the App Gateway subnet"
  value       = var.vnet.app_gw_subnet.name
}

output "app_gw_subnet_prefix" {
  description = "Address prefix of the App Gateway subnet"
  value       = var.vnet.app_gw_subnet.create ? azurerm_subnet.app_gw_subnet[0].address_prefixes[0] : data.azurerm_subnet.app_gw_subnet[0].address_prefixes[0]
}

# When this VNet is used as a hub (shared_vpc_host = true), identifier for the host (Azure: vnet_id).
output "shared_vpc_host_project_id" {
  description = "Host identifier: VNet ID when shared_vpc_host = true (Azure); null otherwise"
  value       = try(var.vnet.shared_vpc_host, false) ? (var.vnet.create ? azurerm_virtual_network.vnet[0].id : data.azurerm_virtual_network.vnet[0].id) : null
}
