output "bucket_name" {
  description = "The name of the GCS bucket"
  value       = var.local_state ? "" : (var.create ? google_storage_bucket.terraform[0].name : data.google_storage_bucket.terraform[0].name)
}

output "bucket_url" {
  description = "The gs:// URL of the bucket"
  value       = var.local_state ? "" : (var.create ? "gs://${google_storage_bucket.terraform[0].name}" : "gs://${data.google_storage_bucket.terraform[0].name}")
}

output "backend_config" {
  description = "Values needed to configure the Terraform GCS backend"
  value = var.local_state ? null : {
    bucket = var.create ? google_storage_bucket.terraform[0].name : data.google_storage_bucket.terraform[0].name
    prefix = "${var.environment}/${var.location}"
    key    = "terraform.tfstate"
  }
}