# Azure dashboards (Azure Managed Grafana). Uploads every *.json in ./dashboards
# (Grafana export format) as a grafana_dashboard.
# Resolves Grafana endpoint via data source (no dependency on 1-platform/2-monitoring).
# Runs when CLOUD_PROVIDER=azure and datadog.enabled = false.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/2-app/2-dashboards/azure"
}

locals {
  root            = include.root.locals.merged
  monitoring_cfg  = try(local.root.monitoring.native, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
}

inputs = {
  enabled                   = !local.datadog_enabled
  resource_group_name       = local.root.resource_scope.name
  cluster_name              = local.root.k8s.name
  grafana_endpoint_override = try(local.monitoring_cfg.grafana_endpoint, null)
  dashboards_folder         = "${get_repo_root()}/iac/2-app/2-dashboards/azure/dashboards"
  grafana_api_token         = get_env("TF_VAR_grafana_api_token", "")
}

exclude {
  if      = local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
