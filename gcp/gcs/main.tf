resource "google_storage_bucket" "raw_router_logs_bucket" {
  name     = var.raw_router_logs_bucket_name
  location = var.region
  force_destroy = var.force_destroy
  uniform_bucket_level_access = true
  storage_class = "STANDARD"

  public_access_prevention = "enforced"

  hierarchical_namespace {
    enabled = true
  }
}