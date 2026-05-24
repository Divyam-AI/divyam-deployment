# Datadog monitors (GCP pipeline). Matched by terragrunt --filter "**/gcp".
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
  source = "${get_repo_root()}/iac/2-app/2-alerts/datadog"
}

inputs = {
  enabled      = true
  rules_folder = "${get_repo_root()}/iac/2-app/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  env = coalesce(try(local.datadog_cfg.monitor_env, null), local.root.env_name)
  cluster_name = coalesce(
    try(local.datadog_cfg.custom_cluster_name, null),
    try(local.datadog_cfg.sandbox_cluster_name, null),
    try(local.root.k8s.name, null),
    "${local.root.deployment_prefix}-k8s-cluster"
  )

  datadog_site    = try(local.datadog_cfg.site, "datadoghq.com")
  datadog_api_key = get_env("TF_VAR_datadog_api_key", "")
  datadog_app_key = get_env("TF_VAR_datadog_app_key", "")

  webhook_urls        = local.webhook_urls
  webhook_name_prefix = "${local.root.deployment_prefix}-pager"

  webhook_custom_payload_enabled = try(local.alerts_cfg.webhook_custom_payload_enabled, true)
  webhook_custom_payload         = try(local.alerts_cfg.webhook_custom_payload, null)

  notify_no_data    = try(local.alerts_cfg.notify_no_data, true)
  no_data_timeframe = try(local.alerts_cfg.no_data_timeframe, 15)
  renotify_interval = try(local.alerts_cfg.renotify_interval, 30)
}

exclude {
  if      = !local.alerts_run || !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
