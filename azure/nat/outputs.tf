output "nat_gateway_enabled" {
  description = "Indicates if nat gateway is created."
  value       = var.create
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].id : null
}

output "nat_gateway_name" {
  description = "The name of the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].name : null
}

output "nat_gateway_location" {
  description = "The Azure region of the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].location : null
}

output "nat_gateway_ip_id" {
  description = "The ID of the associated public IP address"
  value       = var.create ? azurerm_public_ip.nat[0].id : null
}

output "nat_gateway_ip" {
  description = "The public IP address used for outbound connections"
  value       = var.create ? azurerm_public_ip.nat[0].ip_address : null
}

output "nat_gateway_resource_group" {
  description = "The resource group containing the NAT Gateway"
  value       = var.create ? azurerm_nat_gateway.nat[0].resource_group_name : null
}
