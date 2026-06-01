# Cloud Monitoring PromQL alert policies. Matched by terragrunt --filter "**/gcp".
# Skipped when datadog.enabled = true. Depends on notification_channels.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
  alerts_run      = try(local.alerts_cfg.create, true) && try(local.alerts_cfg.enabled, false)
}

terraform {
  source = "${get_repo_root()}/iac/2-app/2-alerts/gcp/alerts"
}

dependency "notification_channels" {
  config_path = "../../notification_channels"
  mock_outputs = {
    notification_channel_ids = []
  }
}

inputs = {
  enabled      = local.alerts_run
  project_id   = local.root.resource_scope.name
  region       = local.root.region
  rules_folder = "${get_repo_root()}/iac/2-app/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  notification_channels = dependency.notification_channels.outputs.notification_channel_ids
}

exclude {
  if      = !local.alerts_run || local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
