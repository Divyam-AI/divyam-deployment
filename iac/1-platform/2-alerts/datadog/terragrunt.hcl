# Datadog alerts. Config from values/defaults.hcl (alerts + datadog). Rules from
# 2-alerts/common/rules (neutral schema). Runs only when alerts.enabled = true AND
# datadog.enabled = true.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/1-platform/2-alerts/datadog"
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
}

inputs = {
  enabled      = try(local.alerts_cfg.enabled, false) && local.datadog_enabled
  rules_folder = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  env          = try(local.datadog_cfg.env, local.root.env_name)
  cluster_name = try(local.root.k8s.name, "${local.root.deployment_prefix}-k8s-cluster")

  datadog_site    = try(local.datadog_cfg.site, "datadoghq.com")
  datadog_api_key = get_env("TF_VAR_datadog_api_key", "")
  datadog_app_key = get_env("TF_VAR_datadog_app_key", "")

  webhook_urls        = try(local.alerts_cfg.webhook_urls, [])
  webhook_name_prefix = "${local.root.deployment_prefix}-pager"
}

# Run only when both flags are on. Inverse of the cloud-native module guards.
exclude {
  if      = !try(local.alerts_cfg.enabled, false) || !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
