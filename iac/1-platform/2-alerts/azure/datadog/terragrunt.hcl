# Datadog monitors (Azure pipeline). Matched by terragrunt --filter "**/azure".
# Skipped when datadog.enabled = false.

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

  webhook_urls = [for u in try(local.alerts_cfg.webhook_urls, []) : u if u != null && u != ""]
}

terraform {
  source = "${get_repo_root()}/iac/1-platform/2-alerts/datadog"
}

inputs = {
  enabled      = true
  rules_folder = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  env = coalesce(try(local.datadog_cfg.monitor_env, null), local.root.env_name)
  cluster_name = try(local.root.k8s.name, "${local.root.deployment_prefix}-k8s-cluster")

  datadog_site    = try(local.datadog_cfg.site, "datadoghq.com")
  datadog_api_key = get_env("TF_VAR_datadog_api_key", "")
  datadog_app_key = get_env("TF_VAR_datadog_app_key", "")

  webhook_urls        = local.webhook_urls
  webhook_name_prefix = "${local.root.deployment_prefix}-pager"

  webhook_custom_payload_enabled = try(local.alerts_cfg.webhook_custom_payload_enabled, true)
  webhook_custom_payload         = try(local.alerts_cfg.webhook_custom_payload, null)
}

exclude {
  if      = !local.alerts_run || !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
