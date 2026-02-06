provider "google" {
  project = var.project_id
  region  = var.region
}

# Notification channel for email alerts
resource "google_monitoring_notification_channel" "email" {
  count = var.email_enabled ? 1 : 0
  display_name = "${var.environment} Alerts Email Notification"
  type         = "email"
  labels = {
    email_address = var.email_alert_email
  }
}

resource "google_monitoring_notification_channel" "webhook_channel" {
  count = var.pager_enabled ? 1 : 0
  display_name = "Zenduty"
  type         = "webhook_tokenauth"

  labels = {
    url = var.pager_webhook_url
  }
}


resource "google_monitoring_notification_channel" "google_chat_channel" {
  count = var.gchat_enabled ? 1 : 0
  display_name = "${var.environment} Alerts Chat Notification"
  type         = "google_chat"

  labels = {
    space = "spaces/${var.gchat_space_id}"
  }
}
