# Datadog dashboards. Each *.json in dashboards/ is uploaded as-is via datadog_dashboard
# using its dashboard_json attribute. Dashboards are produced offline (e.g. exported from
# the Datadog UI / scripts/datadog_dashboard_bulk.sh) and stored verbatim in dashboards/.
#
# Runs only when datadog.enabled = true. See terragrunt.hcl.
#
# Provider requirements are declared in zz_providers_override.tf (override file) to
# coexist with the terraform {} block that root.hcl generates in provider.tf.

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.${var.datadog_site}/"
}

locals {
  dashboard_files = fileset(var.dashboards_folder, "*.json")
  dashboards = {
    for f in local.dashboard_files :
    trimsuffix(basename(f), ".json") => file("${var.dashboards_folder}/${f}")
  }
}

resource "datadog_dashboard_json" "dashboards" {
  for_each  = var.enabled ? local.dashboards : {}
  dashboard = each.value
  # `dashboard` content includes its own id/title/widgets; provider parses it and
  # creates/updates the matching dashboard in the target org.
}
