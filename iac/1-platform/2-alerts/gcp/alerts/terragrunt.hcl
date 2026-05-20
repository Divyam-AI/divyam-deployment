# GCP alerts. Config from values/defaults.hcl (alerts). Rules from 2-alerts/common/rules
# (neutral schema). Depends on 2-alerts/gcp/notification_channels.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "notification_channels" {
  config_path = "../notification_channels"
  mock_outputs = {
    notification_channel_ids = []
  }
}

dependency "k8s" {
  config_path                             = "../../../1-k8s/gcp"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/iac/1-platform/2-alerts/gcp/alerts"
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
}

inputs = {
  enabled      = try(local.alerts_cfg.enabled, false)
  project_id   = local.root.resource_scope.name
  region       = local.root.region
  rules_folder = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  notification_channels = dependency.notification_channels.outputs.notification_channel_ids
}

exclude {
  if      = !try(local.alerts_cfg.enabled, false) || local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
