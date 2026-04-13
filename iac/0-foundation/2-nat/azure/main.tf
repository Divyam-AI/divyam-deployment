# Azure NAT Gateway — public IP + NAT gateway, associated to VNet subnets (source: 1-old/nat).

locals {
  # Names used when create = true (constructed from prefix)
  nat_ip_name      = "${var.resource_name_prefix}-nat-ip"
  nat_gateway_name = "${var.resource_name_prefix}-nat-gateway"

  # Names used when create = false (explicitly provided; fall back to prefix-derived if not set)
  lookup_nat_gateway_name = coalesce(var.nat_gateway_name, local.nat_gateway_name)
  lookup_nat_ip_name      = coalesce(var.nat_public_ip_name, local.nat_ip_name)
  lookup_resource_group   = coalesce(var.lookup_resource_group_name, var.resource_group_name)
  tag_context_base  = merge(var.tag_globals, var.tag_context)
  rendered_tags_nat_ip = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.nat_ip_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
  rendered_tags_nat_gateway = { for k, v in var.common_tags : k => replace(v, "/#\\{([^}]+)\\}/", lookup(merge(local.tag_context_base, { resource_name = local.nat_gateway_name }), try(regex("#\\{([^}]+)\\}", v)[0], ""), "")) }
}

resource "azurerm_public_ip" "nat" {
  count = var.create ? 1 : 0

  name                = local.nat_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.rendered_tags_nat_ip
}

resource "azurerm_nat_gateway" "nat" {
  count = var.create ? 1 : 0

  name                = local.nat_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"

  tags = local.rendered_tags_nat_gateway
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

data "azurerm_nat_gateway" "nat" {
  count               = var.create ? 0 : 1
  name                = local.lookup_nat_gateway_name
  resource_group_name = local.lookup_resource_group
}

data "azurerm_public_ip" "nat" {
  count               = var.create ? 0 : 1
  name                = local.lookup_nat_ip_name
  resource_group_name = local.lookup_resource_group
}
