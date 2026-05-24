# Standalone Datadog alerts entry (optional). Prefer the cloud-filtered units instead:
#   - Azure: 3-alerts/azure/datadog/terragrunt.hcl
#   - GCP:   3-alerts/gcp/alerts/datadog/terragrunt.hcl
# Set TG_STANDALONE_DATADOG_ALERTS=1 to plan/apply this path directly (avoids duplicate
# monitors if you also run 3-alerts/azure or gcp/alerts with datadog.enabled).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/2-app/2-alerts/datadog"
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
  alerts_run      = try(local.alerts_cfg.create, true) && try(local.alerts_cfg.enabled, false)
  # Default excluded so run-all uses 3-alerts/<cloud>/ instead of this duplicate path.
  standalone_mode = get_env("TG_STANDALONE_DATADOG_ALERTS", "0") == "1"
}

inputs = {
  enabled      = try(local.alerts_cfg.enabled, false) && local.datadog_enabled
  rules_folder = "${get_repo_root()}/iac/2-app/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  # Monitor env tag follows deployment env_name (e.g. prod), not datadog.env (Agent tag, often dev).
  env = coalesce(try(local.datadog_cfg.monitor_env, null), local.root.env_name)
  cluster_name = try(local.root.k8s.name, "${local.root.deployment_prefix}-k8s-cluster")

  datadog_site    = try(local.datadog_cfg.site, "datadoghq.com")
  datadog_api_key = get_env("TF_VAR_datadog_api_key", "")
  datadog_app_key = get_env("TF_VAR_datadog_app_key", "")

  webhook_urls        = try(local.alerts_cfg.webhook_urls, [])
  webhook_name_prefix = "${local.root.deployment_prefix}-pager"

  webhook_custom_payload_enabled = try(local.alerts_cfg.webhook_custom_payload_enabled, true)
  webhook_custom_payload         = try(local.alerts_cfg.webhook_custom_payload, null)

  notify_no_data    = try(local.alerts_cfg.notify_no_data, true)
  no_data_timeframe = try(local.alerts_cfg.no_data_timeframe, 15)
  renotify_interval = try(local.alerts_cfg.renotify_interval, 30)
}

exclude {
  if      = !local.standalone_mode || !local.alerts_run || !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
