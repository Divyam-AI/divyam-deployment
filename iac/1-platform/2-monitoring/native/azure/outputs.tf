output "monitor_workspace_name" {
  description = "Azure Monitor workspace name for Prometheus metrics."
  value       = local.metrics_on ? local.amw_name_out : null
}

output "monitor_workspace_id" {
  description = "Azure Monitor workspace resource ID."
  value       = local.metrics_on ? local.amw_id : null
}

output "grafana_endpoint" {
  description = "Azure Managed Grafana endpoint URL."
  value = local.create_amw ? azurerm_dashboard_grafana.grafana["enabled"].endpoint : (
    local.metrics_on && var.grafana_endpoint_override != null && var.grafana_endpoint_override != "" ? var.grafana_endpoint_override : null
  )
}

output "grafana_name" {
  value = local.create_amw ? azurerm_dashboard_grafana.grafana["enabled"].name : null
}

output "grafana_id" {
  value = local.create_amw ? azurerm_dashboard_grafana.grafana["enabled"].id : null
}
