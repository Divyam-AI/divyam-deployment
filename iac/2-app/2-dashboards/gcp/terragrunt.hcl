# GCP dashboards. Uploads every *.json in ./dashboards (GCM-native format) as a
# google_monitoring_dashboard. Runs when CLOUD_PROVIDER=gcp and datadog.enabled = false.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/2-app/2-dashboards/gcp"
}

locals {
  root            = include.root.locals.merged
  datadog_enabled = try(local.root.datadog.enabled, false)
}

inputs = {
  enabled           = !local.datadog_enabled
  project_id        = local.root.resource_scope.name
  region            = local.root.region
  dashboards_folder = "${get_repo_root()}/iac/2-app/2-dashboards/gcp/dashboards"
}

exclude {
  if      = local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
