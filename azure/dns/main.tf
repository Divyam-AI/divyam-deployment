# Application Gateway data
data "azurerm_application_gateway" "appgw" {
  name                = var.app_gateway_name
  resource_group_name = var.resource_group_name
}

# Router zone
resource "azurerm_private_dns_zone" "router_zone" {
  name                = var.router_dns_zone
  resource_group_name = var.resource_group_name
}

# Dashboard zone
resource "azurerm_private_dns_zone" "dashboard_zone" {
  name                = var.dashboard_dns_zone
  resource_group_name = var.resource_group_name
}

# Router zone dns record
resource "azurerm_private_dns_a_record" "router_appgw" {
  name                = "${azurerm_private_dns_zone.router_zone.name}-a-record"
  zone_name           = azurerm_private_dns_zone.router_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [var.app_gateway_lb_ip]
}

# Dashboard zone dns record
resource "azurerm_private_dns_a_record" "dashboard_appgw" {
  name                = "${azurerm_private_dns_zone.dashboard_zone.name}-a-record"
  zone_name           = azurerm_private_dns_zone.dashboard_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [var.app_gateway_lb_ip]
}


resource "azurerm_private_dns_zone_virtual_network_link" "router_zone_vnet_link" {
  name                  = "${azurerm_private_dns_zone.router_zone.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.router_zone.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "dashboard_zone_vnet_link" {
  name                  = "${azurerm_private_dns_zone.dashboard_zone.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dashboard_zone.name
  virtual_network_id    = var.vnet_id
}
