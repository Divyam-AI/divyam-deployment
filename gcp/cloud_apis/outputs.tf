output "enabled_api_services" {
  value = keys(google_project_service.enabled_apis)
}