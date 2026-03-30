output "instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.default.name
}

output "connection_name" {
  description = "Connection name of the Cloud SQL instance (project:region:name)"
  value       = google_sql_database_instance.default.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance (from VPC peering)."
  value       = google_sql_database_instance.default.private_ip_address
}

output "database_name" {
  description = "Name of the initial database"
  value       = google_sql_database.default.name
}
