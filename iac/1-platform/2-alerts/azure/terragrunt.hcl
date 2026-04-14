# Azure alerts. Config from values/defaults.hcl (alerts). Rules from 2-alerts/common/alerts. Tags like 1-k8s.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/1-platform/2-alerts/azure"
}

dependency "k8s" {
  config_path = "../../1-k8s/azure"
  mock_outputs = {
    monitor_workspace_name = "mock-workspace"
    monitor_workspace_id   = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Monitor/accounts/mock"
  }
}

locals {
  root       = include.root.locals.merged
  alerts_cfg = try(local.root.alerts, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
  nc         = try(local.alerts_cfg.notification_channels, {})
  # Pass null when empty so dynamic blocks skip the receiver
  pager_url  = try(local.nc.pager_webhook_url, "") != "" ? local.nc.pager_webhook_url : null
  gchat_id   = try(local.nc.gchat_space_id, "") != "" ? local.nc.gchat_space_id : null
  email_addr = try(local.nc.email_alert_email, "") != "" ? local.nc.email_alert_email : null
  slack_url  = try(local.nc.slack_webhook_url, "") != "" ? local.nc.slack_webhook_url : null
}

inputs = {
  location                      = local.root.region
  resource_group_name           = local.root.resource_scope.name
  environment                  = local.root.env_name
  common_tags                   = try(include.root.inputs.common_tags, {})
  tag_globals                   = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = "${local.root.deployment_prefix}-alerts"
  }

  azure_monitor_workspace_name = dependency.k8s.outputs.monitor_workspace_name
  azure_monitor_workspace_id   = dependency.k8s.outputs.monitor_workspace_id
  resource_name_prefix         = local.root.deployment_prefix
  alerts_folder                = "${get_repo_root()}/iac/1-platform/2-alerts/common/alerts"

  notification_pager_webhook_url  = local.pager_url
  notification_gchat_space_id     = local.gchat_id
  notification_email_alert_email   = local.email_addr
  notification_slack_webhook_url   = local.slack_url
}

exclude {
  if      = !try(local.alerts_cfg.enabled, false) || local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
