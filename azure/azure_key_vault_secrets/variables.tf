variable "azure_key_vault_id" {
  description = "The Azure Key Vault ID"
  type        = string
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