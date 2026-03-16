variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for Key Vault (when creating vault)"
  type        = string
}

# When set, secrets are created in this Key Vault. When null, a new Key Vault is created using key_vault_name.
variable "key_vault_id" {
  description = "Existing Key Vault ID. If null and create_vault is false, Key Vault is looked up by key_vault_name."
  type        = string
  default     = null
}

variable "key_vault_name" {
  description = "Key Vault name (used when creating vault or when create_vault is false to look up existing vault)."
  type        = string
  default     = null
}

# When false, do not create a new Key Vault; use key_vault_name to look up existing vault (or key_vault_id if set).
variable "create_vault" {
  description = "If true, create a new Key Vault. If false, use key_vault_name to get existing vault."
  type        = bool
  default     = true
}

# When false, do not create or manage secrets in the vault.
variable "create_secrets" {
  description = "If true, create Key Vault secrets. If false, do not create or update secrets."
  type        = bool
  default     = true
}

# Single object passed through to common module (built in one place: secrets_input.hcl).
variable "secrets_input" {
  description = "Secrets input for common module (env + all divyam_* values). Passed from Terragrunt."
  type        = any
  sensitive   = true
}

# Router-requests-logs storage account name from defaults.hcl (divyam_object_storages type = \"router-requests-logs\"). When set, looked up in Azure and connection string merged into secrets.
variable "router_requests_logs_storage_account_name" {
  description = "Azure storage account name for router-requests-logs (from defaults.hcl). Looked up in Azure to get connection string for Key Vault secret."
  type        = string
  default     = null
}

# Path to common module (set by Terragrunt so it works in cache).
variable "common_module_source" {
  description = "Path to the common module (set from get_terragrunt_dir()/../common by Terragrunt)."
  type        = string
}

