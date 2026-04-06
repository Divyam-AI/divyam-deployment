# User-Assigned Identity Client IDs (used by helm_charts for workload identity)
output "uai_client_ids" {
  description = "Map from UAI output key (e.g. prometheus-dev-sa_uai_client_id) to client ID."
  sensitive   = true
  value = {
    for sa_name in local.service_account_ids :
    "${sa_name}_uai_client_id" => azurerm_user_assigned_identity.identities[sa_name].client_id
  }
}

# User-Assigned Identity IDs (for reference)
output "uai_ids" {
  description = "Map from service account name to UAI resource ID."
  value = {
    for sa_name in local.service_account_ids :
    sa_name => azurerm_user_assigned_identity.identities[sa_name].id
  }
}

# Service accounts map for consumers (namespace + roles)
output "service_accounts" {
  description = "Map of service account names to namespace and roles."
  value       = local.service_accounts
}
