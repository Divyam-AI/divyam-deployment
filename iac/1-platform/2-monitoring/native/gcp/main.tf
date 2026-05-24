# GCP native observability: project log bucket retention.
# GKE logging components and Managed Prometheus are configured on the cluster in 1-k8s/gcp
# (coupled to google_container_cluster); toggled via k8s.observability in values.

locals {
  tag_context_base = merge(var.tag_globals, var.tag_context)
}

resource "google_logging_project_bucket_config" "default_bucket" {
  count          = var.enabled && var.manage_project_log_bucket ? 1 : 0
  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = min(3650, max(1, var.logs_retention_days))
}
