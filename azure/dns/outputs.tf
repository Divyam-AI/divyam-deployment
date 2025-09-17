output "router_dns_zone" {
  description = "The router DNS zone."
  value       = azurerm_private_dns_zone.router_zone.name
}

output "dashboard_dns_zone" {
  description = "The dashboard DNS zone."
  value       = azurerm_private_dns_zone.dashboard_zone.name
}

output "router_dns_zone_id" {
  description = "The ID of the router DNS zone."
  value       = azurerm_private_dns_zone.router_zone.id
}

output "dashboard_dns_zone_id" {
  description = "The ID of the dashboard DNS zone."
  value       = azurerm_private_dns_zone.dashboard_zone.id
}

output "router_dns_a_record_fqdn" {
  description = "The FQDN of the router A record."
  value       = azurerm_private_dns_a_record.router_appgw.fqdn
}

output "dashboard_dns_a_record_fqdn" {
  description = "The FQDN of the dashboard A record."
  value       = azurerm_private_dns_a_record.dashboard_appgw.fqdn
}

output "router_zone_virtual_network_link_id" {
  description = "The ID of the virtual network link for the router DNS zone."
  value       = azurerm_private_dns_zone_virtual_network_link.router_zone_vnet_link.id
}

output "dashboard_zone_virtual_network_link_id" {
  description = "The ID of the virtual network link for the dashboard DNS zone."
  value       = azurerm_private_dns_zone_virtual_network_link.dashboard_zone_vnet_link.id
}
