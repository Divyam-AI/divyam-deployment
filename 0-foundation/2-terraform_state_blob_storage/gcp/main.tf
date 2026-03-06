# Look up the existing GCS bucket when create = false.
data "google_storage_bucket" "terraform" {
  count   = var.create ? 0 : 1
  name    = var.bucket_name
  project = var.project_id
}

resource "google_storage_bucket" "terraform" {
  count   = var.create ? 1 : 0
  name    = var.bucket_name
  project = var.project_id

  location                    = var.location
  uniform_bucket_level_access  = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  public_access_prevention = "enforced"

  labels = local.rendered_tags

  lifecycle {
    prevent_destroy = true
  }
}
