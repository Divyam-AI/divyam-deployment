# Azure Monitor Prometheus alert rules. Matched by terragrunt --filter "**/azure".
# Skipped when datadog.enabled = true.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
  alerts_run      = try(local.alerts_cfg.create, true) && try(local.alerts_cfg.enabled, false)

  webhook_urls = [for u in try(local.alerts_cfg.webhook_urls, []) : u if u != null && u != ""]
}

terraform {
  source = "${get_repo_root()}/iac/1-platform/2-alerts/azure"
}

dependency "k8s" {
  config_path = "../../../1-k8s/azure"
  mock_outputs = {
    monitor_workspace_name = "mock-workspace"
    monitor_workspace_id   = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Monitor/accounts/mock"
  }
}

inputs = {
  location            = local.root.region
  resource_group_name = local.root.resource_scope.name
  environment         = local.root.env_name
  common_tags         = try(include.root.inputs.common_tags, {})
  tag_globals         = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = "${local.root.deployment_prefix}-alerts"
  }

  azure_monitor_workspace_name = dependency.k8s.outputs.monitor_workspace_name
  azure_monitor_workspace_id   = dependency.k8s.outputs.monitor_workspace_id
  resource_name_prefix         = local.root.deployment_prefix
  rules_folder                 = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"

  webhook_urls = local.webhook_urls
}

exclude {
  if      = !local.alerts_run || local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
