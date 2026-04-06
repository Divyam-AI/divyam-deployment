# Enable GCP APIs (equivalent to gcloud services enable).
# Run early in foundation, after 0-resource_scope so project_id exists.
resource "google_project_service" "enabled_apis" {
  for_each = var.enabled ? toset(var.apis) : toset([])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
