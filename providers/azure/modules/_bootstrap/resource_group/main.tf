locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }
}

resource "azurerm_resource_group" "rd" {
  name     = var.resource_group_name
  location = var.location


  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = var.resource_group_name
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }

  lifecycle {
    prevent_destroy = true
  }
}