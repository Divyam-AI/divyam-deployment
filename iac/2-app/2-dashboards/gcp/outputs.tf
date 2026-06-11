output "dashboard_names" {
  description = "Map of dashboard file basename -> created GCM dashboard resource name."
  value       = { for k, d in google_monitoring_dashboard.dashboards : k => d.name }
}

output "dashboards_count" {
  description = "Number of GCP Cloud Monitoring dashboards uploaded."
  value       = length(google_monitoring_dashboard.dashboards)
}
