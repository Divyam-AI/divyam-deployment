# GCP notification channels. Config from values/defaults.hcl alerts.webhook_urls.
# Run before 2-alerts/gcp/alerts.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "k8s" {
  config_path                             = "../../../1-k8s/gcp"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/iac/1-platform/2-alerts/gcp/notification_channels"
}

locals {
  root            = include.root.locals.merged
  alerts_cfg      = try(local.root.alerts, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
}

inputs = {
  project_id   = local.root.resource_scope.name
  region       = local.root.region
  environment  = local.root.env_name
  webhook_urls = try(local.alerts_cfg.webhook_urls, [])
}

exclude {
  if      = !try(local.alerts_cfg.enabled, false) || local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
