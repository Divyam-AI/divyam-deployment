locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

resource "azurerm_public_ip" "nat" {
  count = var.create ? 1 : 0

  name                 = "${var.resource_name_prefix}-nat-ip"
  location             = var.location
  resource_group_name  = var.resource_group_name
  allocation_method    = "Static"
  sku                  = "Standard"

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name           = "${var.resource_name_prefix}-nat-ip"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_nat_gateway" "nat" {
  count = var.create ? 1 : 0

  name                 = "${var.resource_name_prefix}-nat-gateway"
  location             = var.location
  resource_group_name  = var.resource_group_name
  sku_name             = "Standard"

  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name           = "${var.resource_name_prefix}-nat-gateway"
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}

resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  count = var.create ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_assoc" {
  count = var.create ? 1 : 0

  subnet_id      = var.subnet_ids[var.vnet_subnet_name]
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}