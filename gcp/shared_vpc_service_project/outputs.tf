output "host_project_id" {
  description = "The ID of the host project to which the service project is attached."
  value       = var.host_project_id
}

output "service_project_id" {
  description = "The ID of the service project attached to the Shared VPC."
  value       = var.service_project_id
}

output "attachment_status" {
  description = "Indicates that the service project is successfully attached to the Shared VPC."
  value       = "Service project ${var.service_project_id} is attached to host project ${var.host_project_id}"
}
