# Single input object so Azure/GCP only pass one variable. Common is the single place for secret keys.

variable "environment" {
  description = "Deployment environment (e.g. dev, preprod, prod). Passed from Azure/GCP root."
  type        = string
}

variable "input" {
  description = "Secrets input: all divyam_* secret values (from TF_VAR_* or Terragrunt)."
  type = object({
    divyam_db_root_password             = optional(string)
    divyam_db_user_name                 = optional(string)
    divyam_db_password                  = string
    divyam_clickhouse_user_name         = optional(string, "default")
    divyam_clickhouse_password          = optional(string, "")
    divyam_superset_pg_password         = optional(string)
    divyam_superset_password = optional(string)
    divyam_jwt_secret_key              = string
    divyam_provider_keys_encryption_key = string
    divyam_openai_billing_admin_api_key = optional(string, "")
    divyam_artifactory_docker_auth     = optional(string, "")
    # Azure only: used by Kafka to Blob storage consumer. Omit or null for GCP.
    router_requests_logs_storage_account_connection_string = optional(string)
  })
}
