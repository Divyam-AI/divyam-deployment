# Single place for secrets_input keys. Included by azure and gcp terragrunt; env overridden in each.
locals {
  cloud_provider = get_env("CLOUD_PROVIDER", "")
  env = get_env("ENV", "")
  secrets_input = merge(
    {
    divyam_db_root_password             = get_env("TF_VAR_divyam_db_root_password", "random_password")
    divyam_db_user_name                 = get_env("TF_VAR_divyam_db_user_name", "divyam-preprod")
    divyam_db_password                  = get_env("TF_VAR_divyam_db_password", "random_password")
    divyam_clickhouse_user_name         = get_env("TF_VAR_divyam_clickhouse_user_name", "default")
    divyam_clickhouse_password          = get_env("TF_VAR_divyam_clickhouse_password", "random_password")
    divyam_superset_pg_password         = get_env("TF_VAR_divyam_superset_pg_password", "random_password")
    divyam_jwt_secret_key              = get_env("TF_VAR_divyam_jwt_secret_key", "random_password")
    divyam_provider_keys_encryption_key = get_env("TF_VAR_divyam_provider_keys_encryption_key", "random_password")
    divyam_openai_billing_admin_api_key = get_env("TF_VAR_divyam_openai_billing_admin_api_key", "random_password")
    # User provided secrets. No default or auto-generation in the secrets module.
    divyam_superset_password              = get_env("TF_VAR_divyam_superset_password")
    divyam_router_admin_password        = get_env("TF_VAR_divyam_router_admin_password")
    divyam_deployment_id                = get_env("TF_VAR_divyam_deployment_id")
    divyam_deployment_api_key           = get_env("TF_VAR_divyam_deployment_api_key")
    },
    # Azure only: Artifactory Docker auth for container registry. Omit for GCP.
    # Env var holds a file path; read its contents so the secret value is stored in the secret manager.
    local.cloud_provider == "azure" ? { divyam_artifactory_docker_auth = file(get_env("TF_VAR_divyam_artifactory_docker_auth")) } : {}
  )
}
