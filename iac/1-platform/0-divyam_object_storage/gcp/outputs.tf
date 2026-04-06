# Merged view of all buckets (created + looked up) for outputs
locals {
  # Keys for google_storage_bucket.this (for import). Key = storage_account_name/bucket_name; storage_account_name from values (e.g. ENV=dev -> divyamdevstorage).
  import_keys_created = keys(local.buckets_flat_created)
  all_bucket_ids = merge(
    { for k, v in google_storage_bucket.this : k => v.id },
    { for k, v in data.google_storage_bucket.existing : k => v.id }
  )
  all_bucket_names = merge(
    { for k, v in google_storage_bucket.this : k => v.name },
    { for k, v in data.google_storage_bucket.existing : k => v.name }
  )
  all_bucket_urls = merge(
    { for k, v in google_storage_bucket.this : k => "gs://${v.name}" },
    { for k, v in data.google_storage_bucket.existing : k => "gs://${v.name}" }
  )
}

output "bucket_ids" {
  description = "Map of bucket key (account_key/bucket_name) to GCS bucket resource ID."
  value       = local.all_bucket_ids
}

output "bucket_names" {
  description = "Map of bucket key to GCS bucket name."
  value       = local.all_bucket_names
}

output "bucket_urls" {
  description = "Map of bucket key to gs:// URL."
  value       = local.all_bucket_urls
}

output "bucket_name_list" {
  description = "List of all bucket names (created + looked up)."
  value = concat(
    [for v in google_storage_bucket.this : v.name],
    [for v in data.google_storage_bucket.existing : v.name]
  )
}

# Backward compatibility: storage identified by type "router-requests-logs" (router_requests_logs_storage_key).
locals {
  router_requests_logs_keys = var.router_requests_logs_storage_key != null ? [for k in keys(local.all_bucket_ids) : k if startswith(k, "${var.router_requests_logs_storage_key}/")] : []
  router_requests_logs_first_key = length(local.router_requests_logs_keys) > 0 ? local.router_requests_logs_keys[0] : null
}

output "router_requests_logs_bucket_id" {
  description = "ID of the first bucket with type 'router-requests-logs' (from divyam_object_storages)."
  value       = local.router_requests_logs_first_key != null ? local.all_bucket_ids[local.router_requests_logs_first_key] : null
}

output "router_requests_logs_bucket_name" {
  description = "Name of the first bucket with type 'router-requests-logs' (from divyam_object_storages)."
  value       = local.router_requests_logs_first_key != null ? local.all_bucket_names[local.router_requests_logs_first_key] : null
}

output "router_requests_logs_bucket_url" {
  description = "gs:// URL for the first bucket with type 'router-requests-logs' (from divyam_object_storages)."
  value       = local.router_requests_logs_first_key != null ? local.all_bucket_urls[local.router_requests_logs_first_key] : null
}

output "router_requests_logs_bucket_names" {
  description = "Bucket names for the storage with type 'router-requests-logs' (from divyam_object_storages)."
  value       = var.router_requests_logs_storage_key != null ? [for k in local.router_requests_logs_keys : local.all_bucket_names[k]] : []
}

# Keys for google_storage_bucket.this (for import). Key = storage_account_name/bucket_name; storage_account_name depends on ENV (e.g. ENV=dev -> divyamdevstorage).
output "import_keys_created" {
  description = "Resource address keys for terraform import. Use: terraform import 'google_storage_bucket.this[\"<key>\"]' projects/<project>/storage/buckets/<bucket-name>"
  value       = local.import_keys_created
}
