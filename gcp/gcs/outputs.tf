output "bucket_name" {
  description = "Name of the created GCS bucket"
  value       = google_storage_bucket.raw_router_logs_bucket.name
}

output "bucket_url" {
  description = "URL of the GCS bucket"
  value       = "gs://${google_storage_bucket.raw_router_logs_bucket.name}"
}