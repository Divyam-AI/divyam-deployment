variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "key_vault_name" {
  description = "Azure Key Vault name. Used to construct the vault URI (https://<name>.vault.azure.net/)."
  type        = string
}

variable "client_secret_ref" {
  description = "Client secret reference for external secrets. Leave empty if not used."
  type        = string
  default     = ""
}

variable "storage_container" {
  description = "Azure storage container name for platform storage_configs."
  type        = string
  default     = ""
}

variable "storage_account" {
  description = "Azure storage account name for platform storage_configs."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure AD tenant ID for workload identity federation."
  type        = string
  default     = ""
}

variable "wif_client_id_map" {
  description = "Map of workload name to Azure UAI client ID for workload identity federation."
  type        = map(string)
  default     = {}
}

variable "cluster_domain" {
  description = "Cluster domain for cross-cluster DNS. Leave empty for in-cluster."
  type        = string
  default     = ""
}

variable "image_pull_secret_enabled" {
  description = "Whether the cluster needs image pull secrets for a private registry."
  type        = bool
  default     = true
}

variable "output_path" {
  description = "Absolute path for the generated provider.yaml file."
  type        = string
}
