provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_logging_project_bucket_config" "default_bucket" {
  bucket_id     = "_Default"
  project       = var.project_id
  retention_days = var.retention_days  # Change to desired retention (1 to 3650)
  location = "global"  # _Default is always in "global"
}