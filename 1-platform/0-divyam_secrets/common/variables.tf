# Single input object so Azure/GCP only pass one variable. Common is the single place for secret keys.

variable "input" {
  description = "Secrets input: env and all divyam_* secret values (from TF_VAR_* or Terragrunt)."
  type = object({
    env                                 = string
    divyam_db_root_password             = optional(string)
    divyam_db_user_name                 = optional(string)
    divyam_db_password                  = string
    divyam_clickhouse_user_name         = optional(string, "default")
    divyam_clickhouse_password          = optional(string, "")
    divyam_superset_pg_password         = optional(string)
    divyam_superset_pg_superset_password = optional(string)
    divyam_jwt_secret_key              = string
    divyam_provider_keys_encryption_key = string
    divyam_openai_billing_admin_api_key = optional(string, "")
    divyam_gar_sa_key                  = string
    # Azure only: used by Kafka to Blob storage consumer. Omit or null for GCP.
    router_requests_logs_storage_account_connection_string = optional(string)
  })
}
