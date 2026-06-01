# Azure dashboards via Azure Managed Grafana.
# Each *.json in dashboards/ is a standard Grafana dashboard export. They are uploaded
# as-is via grafana_dashboard.
#
# Auth: Azure Managed Grafana exposes a Grafana-compatible API at <endpoint>. Create a
# Grafana service account + token in the Managed Grafana instance and pass it via
# TF_VAR_grafana_api_token. Alternative: use Azure AD identity; not implemented here.
#
# Runs only when datadog.enabled = false.
#
# Provider requirements are declared in zz_providers_override.tf (override file) to
# coexist with the terraform {} block that root.hcl generates in provider.tf.

provider "grafana" {
  url  = local.grafana_endpoint_resolved
  auth = var.grafana_api_token
}

locals {
  dashboard_files = fileset(var.dashboards_folder, "*.json")
  dashboards = {
    for f in local.dashboard_files :
    trimsuffix(basename(f), ".json") => file("${var.dashboards_folder}/${f}")
  }
}

resource "grafana_dashboard" "dashboards" {
  for_each    = var.enabled ? local.dashboards : {}
  config_json = each.value
  overwrite   = true
}
