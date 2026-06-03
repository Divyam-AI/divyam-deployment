# GCP dashboards. Each *.json in dashboards/ is uploaded as-is via
# google_monitoring_dashboard using its dashboard_json attribute. Dashboards are
# produced offline in the Google Cloud Monitoring native JSON format and stored
# verbatim in dashboards/.
#
# Runs only when datadog.enabled = false (Datadog has its own dashboards path).

locals {
  dashboard_files = fileset(var.dashboards_folder, "*.json")
  dashboards = {
    for f in local.dashboard_files :
    trimsuffix(basename(f), ".json") => file("${var.dashboards_folder}/${f}")
  }
}

resource "google_monitoring_dashboard" "dashboards" {
  for_each       = var.enabled ? local.dashboards : {}
  project        = var.project_id
  dashboard_json = each.value
}
