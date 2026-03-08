# GCP notification channels. Config from values/defaults.hcl alerts.notification_channels. Run before 2-alerts/gcp/alerts.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/2-alerts/gcp/notification_channels"
}

locals {
  root = include.root.locals.merged
  nc   = try(local.root.alerts.notification_channels, {})
}

inputs = {
  project_id        = local.root.resource_scope.name
  region            = local.root.region
  environment       = local.root.env_name
  pager_enabled     = try(local.nc.pager_enabled, false)
  pager_webhook_url = try(local.nc.pager_webhook_url, "")
  gchat_enabled     = try(local.nc.gchat_enabled, false)
  gchat_space_id    = try(local.nc.gchat_space_id, "")
  email_enabled     = try(local.nc.email_enabled, false)
  email_alert_email = try(local.nc.email_alert_email, "")
  slack_enabled     = try(local.nc.slack_enabled, false)
  slack_webhook_url = try(local.nc.slack_webhook_url, "")
}