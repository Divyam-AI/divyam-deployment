locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

# Router zone
resource "azurerm_private_dns_zone" "router_zone" {
  name                = var.router_dns_zone
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.router_dns_zone
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

# Dashboard zone
resource "azurerm_private_dns_zone" "dashboard_zone" {
  name                = var.dashboard_dns_zone
  resource_group_name = var.resource_group_name
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.dashboard_dns_zone
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

# Router zone dns record
resource "azurerm_private_dns_a_record" "router_appgw" {
  name                = "${azurerm_private_dns_zone.router_zone.name}-a-record"
  zone_name           = azurerm_private_dns_zone.router_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [var.app_gateway_lb_ip]
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${azurerm_private_dns_zone.router_zone.name}-a-record"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

# Dashboard zone dns record
resource "azurerm_private_dns_a_record" "dashboard_appgw" {
  name                = "${azurerm_private_dns_zone.dashboard_zone.name}-a-record"
  zone_name           = azurerm_private_dns_zone.dashboard_zone.name
  resource_group_name = var.resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [var.app_gateway_lb_ip]
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${azurerm_private_dns_zone.dashboard_zone.name}-a-record"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}


resource "azurerm_private_dns_zone_virtual_network_link" "router_zone_vnet_link" {
  name                  = "${azurerm_private_dns_zone.router_zone.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.router_zone.name
  virtual_network_id    = var.vnet_id
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${azurerm_private_dns_zone.router_zone.name}-vnet-link"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "dashboard_zone_vnet_link" {
  name                  = "${azurerm_private_dns_zone.dashboard_zone.name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dashboard_zone.name
  virtual_network_id    = var.vnet_id
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = "${azurerm_private_dns_zone.dashboard_zone.name}-vnet-link"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}
