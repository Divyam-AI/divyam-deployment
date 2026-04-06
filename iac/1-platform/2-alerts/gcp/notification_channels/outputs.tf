output "notification_channel_email" {
  description = "Notification channel for email alerts"
  value       = var.email_enabled ? google_monitoring_notification_channel.email[0].name : ""
}

output "notification_channel_webhook" {
  description = "Notification channel for webhook alerts"
  value       = var.pager_enabled ? google_monitoring_notification_channel.webhook_channel[0].name : ""
}

output "notification_channel_google_chat" {
  description = "Notification channel for Google Chat alerts"
  value       = var.gchat_enabled ? google_monitoring_notification_channel.google_chat_channel[0].name : ""
}

output "notification_channel_slack" {
  description = "Notification channel for Slack alerts"
  value       = var.slack_enabled ? google_monitoring_notification_channel.slack_channel[0].name : ""
}
