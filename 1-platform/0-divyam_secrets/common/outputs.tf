output "secrets" {
  description = "Map of secret names to values for use by cloud-specific modules (Key Vault, Secret Manager)."
  value       = local.secrets
  sensitive   = true
}

# Non-sensitive list of secret names so cloud modules can use it for for_each (sensitive maps cannot be used for for_each).
output "secret_names" {
  description = "List of secret names (keys). Use for for_each; look up value via secrets[name]."
  value       = nonsensitive(keys(local.secrets))
}
