output "monitor_ids" {
  description = "Map of alert name -> Datadog monitor ID."
  value       = { for k, m in datadog_monitor.alerts : k => m.id }
}

output "alerts_enabled" {
  description = "Indicates if Datadog alerts module is active."
  value       = var.enabled
}
