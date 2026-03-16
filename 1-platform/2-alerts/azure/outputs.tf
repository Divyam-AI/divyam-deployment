output "action_group_id" {
  description = "ID of the alerts action group"
  value       = azurerm_monitor_action_group.alerts.id
}

output "alerts_enabled" {
  description = "Indicates if alerts are enabled"
  value       = true
}
