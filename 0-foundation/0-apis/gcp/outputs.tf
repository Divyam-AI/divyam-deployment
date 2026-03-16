output "enabled_api_services" {
  description = "List of enabled GCP API service names"
  value       = var.enabled ? keys(google_project_service.enabled_apis) : []
}
