output "dashboard_uids" {
  description = "Map of dashboard file basename -> Grafana dashboard UID."
  value       = { for k, d in grafana_dashboard.dashboards : k => d.uid }
}

output "dashboards_count" {
  description = "Number of Grafana dashboards uploaded."
  value       = length(grafana_dashboard.dashboards)
}
