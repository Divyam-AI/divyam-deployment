# GCP notification channels. One google_monitoring_notification_channel of type
# webhook_tokenauth is created per webhook URL (pager / Zenduty-style endpoints).

locals {
  webhooks = {
    for idx, url in var.webhook_urls : "webhook-${idx}" => url
    if url != null && url != ""
  }
}

resource "google_monitoring_notification_channel" "webhooks" {
  for_each     = local.webhooks
  project      = var.project_id
  display_name = "${var.environment} ${each.key}"
  type         = "webhook_tokenauth"
  labels = {
    url = each.value
  }
}
