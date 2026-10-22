output "project_id" {
  value = var.project_id
}

output "cluster_name" {
  value = var.cluster_name
}

output "cloudsql_backup_metric_type" {
  description = "Metric type for alert policies, or null when the metric is not created."
  value       = local.cloudsql_backup_metric_enabled ? "logging.googleapis.com/user/${var.cloudsql_backup_metric_name}" : null
}

output "uptime_check_ids" {
  description = "Uptime check config ids by name (empty when none are configured)."
  value       = { for name, check in google_monitoring_uptime_check_config.this : name => check.uptime_check_id }
}

output "managed_prometheus_enabled" {
  value = var.enabled && var.enable_managed_prometheus
}
