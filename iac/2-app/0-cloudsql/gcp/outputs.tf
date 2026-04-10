output "instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = var.create ? google_sql_database_instance.default[0].name : null
}

output "connection_name" {
  description = "Connection name of the Cloud SQL instance (project:region:name)"
  value       = var.create ? google_sql_database_instance.default[0].connection_name : null
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance (from VPC peering)."
  value       = var.create ? google_sql_database_instance.default[0].private_ip_address : null
}

output "database_name" {
  description = "Name of the initial database"
  value       = var.create ? google_sql_database.default[0].name : null
}
