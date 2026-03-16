output "secret_ids" {
  description = "Map of secret name to GCP Secret Manager secret resource name."
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.id }
}

output "secret_names" {
  description = "List of secret IDs in Secret Manager."
  value       = [for k in google_secret_manager_secret.secrets : k]
}
