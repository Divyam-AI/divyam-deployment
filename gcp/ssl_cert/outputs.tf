output "project" {
  description = "The GCP project ID used."
  value       = var.project_id
}

output "managed_ssl_certificate_name" {
  description = "The name of the Google-managed SSL certificate."
  value       = var.enabled ? google_compute_managed_ssl_certificate.global_managed_ssl[0].name : ""
}

output "managed_ssl_certificate_status" {
  description = "The managed block of the Google-managed SSL certificate, which may include status and domain info."
  value       = var.enabled ? google_compute_managed_ssl_certificate.global_managed_ssl[0].managed : []
}