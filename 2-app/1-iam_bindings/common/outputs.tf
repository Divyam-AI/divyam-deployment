output "service_accounts" {
  description = "Map of service account names (env-suffixed) to namespace and roles."
  value       = local.service_accounts
}

output "base_service_accounts" {
  description = "Base service account definitions (no env suffix)."
  value       = local.base_service_accounts
}
