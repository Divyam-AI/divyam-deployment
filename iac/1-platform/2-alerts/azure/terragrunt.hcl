# Alerts for Azure deployments. When datadog.enabled = true, this unit runs the Datadog
# module (so `terragrunt run-all --filter "**/azure"` still applies monitors). Otherwise
# it runs Azure Monitor Prometheus rule groups.
#
# Notifications: alerts.webhook_urls (list of pager-style webhook URLs).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
  alerts_run      = try(local.alerts_cfg.create, true) && try(local.alerts_cfg.enabled, false)
  use_datadog     = local.alerts_run && local.datadog_enabled

  webhook_urls = [for u in try(local.alerts_cfg.webhook_urls, []) : u if u != null && u != ""]

  datadog_module = "${get_repo_root()}/iac/1-platform/2-alerts/datadog"
  azure_module   = "${get_repo_root()}/iac/1-platform/2-alerts/azure"
  rules_folder   = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"

  datadog_inputs = {
    enabled      = true
    rules_folder = local.rules_folder
    exclude_list = try(local.alerts_cfg.exclude_list, [])

    env          = try(local.datadog_cfg.env, local.root.env_name)
    cluster_name = try(local.root.k8s.name, "${local.root.deployment_prefix}-k8s-cluster")

    datadog_site    = try(local.datadog_cfg.site, "datadoghq.com")
    datadog_api_key = get_env("TF_VAR_datadog_api_key", "")
    datadog_app_key = get_env("TF_VAR_datadog_app_key", "")

    webhook_urls        = local.webhook_urls
    webhook_name_prefix = "${local.root.deployment_prefix}-pager"

    webhook_custom_payload_enabled = try(local.alerts_cfg.webhook_custom_payload_enabled, true)
    webhook_custom_payload         = try(local.alerts_cfg.webhook_custom_payload, null)
  }

  # dependency.* cannot be referenced inside locals; workspace IDs merged in inputs below.
  azure_inputs_static = {
    location            = local.root.region
    resource_group_name = local.root.resource_scope.name
    environment         = local.root.env_name
    common_tags         = try(include.root.inputs.common_tags, {})
    tag_globals         = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = "${local.root.deployment_prefix}-alerts"
    }

    resource_name_prefix = local.root.deployment_prefix
    rules_folder         = local.rules_folder
    webhook_urls         = local.webhook_urls
  }
}

terraform {
  source = local.use_datadog ? local.datadog_module : local.azure_module
}

dependency "k8s" {
  enabled = !local.use_datadog

  config_path = "../../1-k8s/azure"
  mock_outputs = {
    monitor_workspace_name = "mock-workspace"
    monitor_workspace_id   = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Monitor/accounts/mock"
  }
}

# jsonencode/jsondecode: Datadog and Azure inputs have different shapes (HCL ternary requires uniform types).
inputs = jsondecode(local.use_datadog ? jsonencode(local.datadog_inputs) : jsonencode(merge(
  local.azure_inputs_static,
  {
    azure_monitor_workspace_name = dependency.k8s.outputs.monitor_workspace_name
    azure_monitor_workspace_id   = dependency.k8s.outputs.monitor_workspace_id
  }
)))

exclude {
  if      = !local.alerts_run
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
