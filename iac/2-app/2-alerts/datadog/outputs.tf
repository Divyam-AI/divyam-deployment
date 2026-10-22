output "monitor_ids" {
  description = "Map of alert name -> Datadog monitor ID. A floored rule maps to its composite monitor, the one that notifies."
  value = merge(
    { for k, m in datadog_monitor.alerts : k => m.id },
    { for k, m in datadog_monitor.composite : k => m.id },
  )
}

output "alerts_enabled" {
  description = "Indicates if Datadog alerts module is active."
  value       = var.enabled
}
