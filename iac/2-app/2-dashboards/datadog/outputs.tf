output "dashboard_ids" {
  description = "Map of dashboard file basename -> created Datadog dashboard ID."
  value       = { for k, d in datadog_dashboard_json.dashboards : k => d.id }
}

output "dashboards_count" {
  description = "Number of Datadog dashboards uploaded."
  value       = length(datadog_dashboard_json.dashboards)
}
