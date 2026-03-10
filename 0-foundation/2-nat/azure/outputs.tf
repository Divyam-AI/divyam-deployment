output "nat_gateway_enabled" {
  description = "Indicates if a NAT gateway is present (created, imported, or pre-existing)."
  value       = var.create ? true : length(data.azurerm_nat_gateway.nat) > 0
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].id : data.azurerm_nat_gateway.nat[0].id
}

output "nat_gateway_name" {
  description = "The name of the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].name : data.azurerm_nat_gateway.nat[0].name
}

output "nat_gateway_location" {
  description = "The Azure region of the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].location : data.azurerm_nat_gateway.nat[0].location
}

output "nat_gateway_ip_id" {
  description = "The ID of the associated public IP address"
  value       = var.create ? azurerm_public_ip.nat[0].id : data.azurerm_public_ip.nat[0].id
}

output "nat_gateway_ip" {
  description = "The public IP address used for outbound connections"
  value       = var.create ? azurerm_public_ip.nat[0].ip_address : data.azurerm_public_ip.nat[0].ip_address
}

output "nat_gateway_resource_group" {
  description = "The resource group containing the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].resource_group_name : data.azurerm_nat_gateway.nat[0].resource_group_name
}
