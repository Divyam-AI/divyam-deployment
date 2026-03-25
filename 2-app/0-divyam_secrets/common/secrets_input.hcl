# Single place for secrets_input keys. Included by azure and gcp terragrunt; env overridden in each.
locals {
  cloud_provider = get_env("CLOUD_PROVIDER", "")
  secrets_input = merge(
    {
    divyam_db_root_password             = get_env("TF_VAR_divyam_db_root_password", "")
    divyam_db_user_name                 = get_env("TF_VAR_divyam_db_user_name", "")
    divyam_db_password                  = get_env("TF_VAR_divyam_db_password", "")
    divyam_clickhouse_user_name         = get_env("TF_VAR_divyam_clickhouse_user_name", "default")
    divyam_clickhouse_password          = get_env("TF_VAR_divyam_clickhouse_password", "")
    divyam_superset_pg_password         = get_env("TF_VAR_divyam_superset_pg_password", "")
    divyam_superset_password            = get_env("TF_VAR_divyam_superset_password", "")
    divyam_jwt_secret_key              = get_env("TF_VAR_divyam_jwt_secret_key", "")
    divyam_provider_keys_encryption_key = get_env("TF_VAR_divyam_provider_keys_encryption_key", "")
    divyam_openai_billing_admin_api_key = get_env("TF_VAR_divyam_openai_billing_admin_api_key", "")
    },
    # Azure only: GAR SA key for container registry. Omit for GCP.
    local.cloud_provider == "azure" ? { divyam_gar_sa_key = get_env("TF_VAR_divyam_gar_sa_key") } : {}
  )
}
