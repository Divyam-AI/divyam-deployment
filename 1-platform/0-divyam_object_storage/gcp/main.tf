locals {
  to_create = { for k, v in var.buckets : k => v if try(v.create, true) }
  to_lookup  = { for k, v in var.buckets : k => v if !try(v.create, true) }

  # Flat set of buckets for create: "account_key/bucket_name" -> { account_key, bucket_name }
  buckets_flat_created = length(local.to_create) > 0 ? merge([
    for acc_key, acc in local.to_create : {
      for b in acc.bucket_names : "${acc_key}/${b}" => { account_key = acc_key, bucket_name = b }
    }
  ]...) : {}

  # Flat set of buckets for lookup (data source)
  buckets_flat_lookup = length(local.to_lookup) > 0 ? merge([
    for acc_key, acc in local.to_lookup : {
      for b in acc.bucket_names : "${acc_key}/${b}" => { account_key = acc_key, bucket_name = b }
    }
  ]...) : {}
}

# --- Create path ---
resource "google_storage_bucket" "this" {
  for_each = local.buckets_flat_created

  name     = each.value.bucket_name
  project  = var.project_id
  location = var.location

  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy
  storage_class               = var.storage_class

  public_access_prevention = "enforced"

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "hierarchical_namespace" {
    for_each = var.hierarchical_namespace_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  labels = local.rendered_tags

  lifecycle {
    prevent_destroy = true
  }
}

# --- Lookup path (create = false): fetch existing buckets from GCP ---
data "google_storage_bucket" "existing" {
  for_each = local.buckets_flat_lookup

  name    = each.value.bucket_name
  project = var.project_id
}
