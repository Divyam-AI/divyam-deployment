# Datadog dashboards. Uploads every *.json in ./dashboards as-is to the Datadog org.
# Runs only when datadog.enabled = true.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/2-app/2-dashboards/datadog"
}

locals {
  root            = include.root.locals.merged
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
}

inputs = {
  enabled           = local.datadog_enabled
  dashboards_folder = "${get_repo_root()}/iac/2-app/2-dashboards/datadog/dashboards"
  datadog_site      = try(local.datadog_cfg.site, "datadoghq.com")
  datadog_api_key   = get_env("TF_VAR_datadog_api_key", "")
  datadog_app_key   = get_env("TF_VAR_datadog_app_key", "")
}

exclude {
  if      = !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
