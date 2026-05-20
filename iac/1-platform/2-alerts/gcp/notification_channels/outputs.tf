output "notification_channel_ids" {
  description = "List of created notification channel IDs (one per webhook URL)."
  value       = [for c in google_monitoring_notification_channel.webhooks : c.id]
}

output "notification_channels_by_name" {
  description = "Map of channel key (webhook-<idx>) -> channel ID."
  value       = { for k, c in google_monitoring_notification_channel.webhooks : k => c.id }
}
