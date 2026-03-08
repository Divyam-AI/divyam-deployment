# Azure NAT Gateway — public IP + NAT gateway, associated to VNet subnets (source: 1-old/nat).

resource "azurerm_public_ip" "nat" {
  count = var.create ? 1 : 0

  name                = "${var.resource_name_prefix}-nat-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.rendered_tags
}

resource "azurerm_nat_gateway" "nat" {
  count = var.create ? 1 : 0

  name                = "${var.resource_name_prefix}-nat-gateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"

  tags = local.rendered_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  count = var.create ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_assoc" {
  for_each = var.create ? { for k, v in var.subnet_ids : k => v if v != null && v != "" } : {}

  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}
