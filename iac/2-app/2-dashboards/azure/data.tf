locals {
  amw_prefix   = join("", [for p in split("-", var.cluster_name) : substr(p, 0, 3)])
  grafana_name = "${local.amw_prefix}-gf"

  grafana_endpoint_resolved = coalesce(
    var.grafana_endpoint_override,
    try(data.azurerm_dashboard_grafana.managed[0].endpoint, null)
  )
}

data "azurerm_dashboard_grafana" "managed" {
  count = var.enabled && (var.grafana_endpoint_override == null || var.grafana_endpoint_override == "") ? 1 : 0

  name                = local.grafana_name
  resource_group_name = var.resource_group_name
}
