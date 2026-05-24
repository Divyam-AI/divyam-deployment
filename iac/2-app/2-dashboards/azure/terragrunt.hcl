# Azure dashboards (Azure Managed Grafana). Uploads every *.json in ./dashboards
# (Grafana export format) as a grafana_dashboard against the Managed Grafana endpoint
# Grafana endpoint from 1-platform/2-monitoring/native/azure. Runs when CLOUD_PROVIDER=azure and
# datadog.enabled = false.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "monitoring" {
  config_path = "../../../1-platform/2-monitoring/native/azure"
  mock_outputs = {
    grafana_endpoint = "https://mock-grafana.eastus.grafana.azure.com"
    grafana_name     = "mock-grafana"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/iac/2-app/2-dashboards/azure"
}

locals {
  root            = include.root.locals.merged
  datadog_enabled = try(local.root.datadog.enabled, false)
}

inputs = {
  enabled           = !local.datadog_enabled
  dashboards_folder = "${get_repo_root()}/iac/2-app/2-dashboards/azure/dashboards"
  grafana_endpoint  = dependency.monitoring.outputs.grafana_endpoint
  grafana_api_token = get_env("TF_VAR_grafana_api_token", "")
}

exclude {
  if      = local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
