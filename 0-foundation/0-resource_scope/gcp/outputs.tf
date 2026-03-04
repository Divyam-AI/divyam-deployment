output "project_id" {
  description = "Created or existing GCP project ID"
  value       = local.project.project_id
}

output "project_number" {
  description = "Numeric project number"
  value       = local.project.number
}
