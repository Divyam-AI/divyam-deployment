output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = azurerm_nat_gateway.nat.id
}

output "nat_gateway_name" {
  description = "The name of the NAT Gateway"
  value       = azurerm_nat_gateway.nat.name
}

output "nat_gateway_location" {
  description = "The Azure region of the NAT Gateway"
  value       = azurerm_nat_gateway.nat.location
}

output "nat_gateway_ip_id" {
  description = "The ID of the associated public IP address"
  value       = azurerm_public_ip.nat.id
}

output "nat_gateway_ip" {
  description = "The public IP address used for outbound connections"
  value       = azurerm_public_ip.nat.ip_address
}

output "nat_gateway_resource_group" {
  description = "The resource group containing the NAT Gateway"
  value       = azurerm_nat_gateway.nat.resource_group_name
}
