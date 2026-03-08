# Service account emails (for Helm / GKE workload identity)
output "service_account_emails" {
  description = "Map of service account name to GCP service account email."
  value = {
    for sa_name in local.service_account_ids :
    sa_name => google_service_account.identities[sa_name].email
  }
}

# Service accounts map for consumers
output "service_accounts" {
  description = "Map of service account names to namespace and roles."
  value       = local.service_accounts
}
