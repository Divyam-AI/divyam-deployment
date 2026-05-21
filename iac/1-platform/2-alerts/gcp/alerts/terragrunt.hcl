# GCP alerts. When datadog.enabled = true, this unit runs the Datadog module (so
# `terragrunt run-all --filter "**/gcp"` still applies monitors). Otherwise it runs
# Cloud Monitoring PromQL alert policies (depends on notification_channels).

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
  gcp_module     = "${get_repo_root()}/iac/1-platform/2-alerts/gcp/alerts"
}

terraform {
  source = local.use_datadog ? local.datadog_module : local.gcp_module
}

dependency "notification_channels" {
  enabled = !local.use_datadog

  config_path = "../notification_channels"
  mock_outputs = {
    notification_channel_ids = []
  }
}

dependency "k8s" {
  enabled = !local.use_datadog

  config_path                             = "../../../1-k8s/gcp"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = local.use_datadog ? {
  enabled      = true
  rules_folder = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"
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
  } : {
  enabled      = local.alerts_run
  project_id   = local.root.resource_scope.name
  region       = local.root.region
  rules_folder = "${get_repo_root()}/iac/1-platform/2-alerts/common/rules"
  exclude_list = try(local.alerts_cfg.exclude_list, [])

  notification_channels = dependency.notification_channels.outputs.notification_channel_ids
}

exclude {
  if      = !local.alerts_run
  actions = ["apply", "plan", "destroy", "refresh", "import", "init"]
}
