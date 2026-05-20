output "alert_policy_ids" {
  description = "Map of alert name -> policy ID"
  value       = { for k, p in google_monitoring_alert_policy.alerts : k => p.id }
}

output "alerts_enabled" {
  description = "Indicates if alerts are enabled."
  value       = var.enabled
}
