# Look up the existing GCS bucket when create = false and not forcing for import.
data "google_storage_bucket" "terraform" {
  count   = var.create || var.import_mode ? 0 : 1
  name    = var.bucket_name
  project = var.project_id
}

resource "google_storage_bucket" "terraform" {
  count   = var.create || var.import_mode ? 1 : 0
  name    = var.bucket_name
  project = var.project_id

  location                    = var.location
  uniform_bucket_level_access  = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  public_access_prevention = "enforced"

  # GCS bucket labels require lowercase keys (see https://cloud.google.com/storage/docs/tags-and-labels#bucket-labels)
  labels = { for k, v in local.rendered_tags : lower(k) => v }

  lifecycle {
    prevent_destroy = true
  }
}
