variable "location" {
  description = "Azure provider location"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "resource_group_name" {
  description = "Resource group to use"
  type        = string
}

variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
}

variable "divyam_db_root_password" {
  type        = string
  description = "Root user password required for example for mysql. If not provided a randomly generated password is used."
  sensitive   = true
  default     = null
}

variable "divyam_db_user_name" {
  type = string
}

variable "divyam_db_password" {
  type      = string
  sensitive = true
}

variable "divyam_clickhouse_user_name" {
  type = string
}

variable "divyam_clickhouse_password" {
  type      = string
  sensitive = true
  # TODO: Figure out a way to get clickhouse to start with password.
  default = ""
}

variable "divyam_superset_pg_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "divyam_superset_pg_superset_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "divyam_jwt_secret_key" {
  type      = string
  sensitive = true
}

variable "divyam_provider_keys_encryption_key" {
  type      = string
  sensitive = true
}

variable "divyam_openai_billing_admin_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "divyam_gar_sa_key" {
  type      = string
  sensitive = true
}