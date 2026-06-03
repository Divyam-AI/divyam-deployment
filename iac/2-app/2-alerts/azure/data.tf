locals {
  amw_prefix = join("", [for p in split("-", var.cluster_name) : substr(p, 0, 3)])
  amw_name   = coalesce(var.azure_monitor_workspace_name, "${local.amw_prefix}-amw")
}

data "azurerm_monitor_workspace" "prometheus" {
  name                = local.amw_name
  resource_group_name = var.resource_group_name
}
