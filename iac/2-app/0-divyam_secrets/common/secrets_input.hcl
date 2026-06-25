# Single place for secrets_input keys. Included by azure and gcp terragrunt, env overridden in each.
locals {
  cloud_provider = get_env("CLOUD_PROVIDER", "")
  env            = get_env("ENV", "")
  # Evalm8 secrets are provisioned only when the evalm8 stack is in scope.
  stack = get_env("STACK", "both")
  secrets_input = merge(
    {
      # Gate for the evalm8 secret keys.
      evalm8_enabled = local.stack != "router"
      # Evalm8 stack secrets, manually passed via TF_VAR_* (main.tf falls back to a random value for a sandbox when unset).
      divyam_lakefs_access_key_id          = get_env("TF_VAR_divyam_lakefs_access_key_id", "")
      divyam_lakefs_secret_access_key      = get_env("TF_VAR_divyam_lakefs_secret_access_key", "")
      divyam_lakefs_auth_encrypt_key       = get_env("TF_VAR_divyam_lakefs_auth_encrypt_key", "")
      divyam_argilla_api_key               = get_env("TF_VAR_divyam_argilla_api_key", "")
      divyam_argilla_auth_secret_key       = get_env("TF_VAR_divyam_argilla_auth_secret_key", "")
      divyam_argilla_default_user_password = get_env("TF_VAR_divyam_argilla_default_user_password", "")
      divyam_evalm8_jwt_secret             = get_env("TF_VAR_divyam_evalm8_jwt_secret", "")
      divyam_evalm8_encryption_key         = get_env("TF_VAR_divyam_evalm8_encryption_key", "")
      divyam_evalm8_admin_password         = get_env("TF_VAR_divyam_evalm8_admin_password", "")
      divyam_db_root_password              = get_env("TF_VAR_divyam_db_root_password", "")
      divyam_db_user_name                  = get_env("TF_VAR_divyam_db_user_name", "divyam-prod")
      divyam_db_password                   = get_env("TF_VAR_divyam_db_password", "")
      divyam_clickhouse_user_name          = get_env("TF_VAR_divyam_clickhouse_user_name", "default")
      divyam_clickhouse_password           = get_env("TF_VAR_divyam_clickhouse_password", "")
      divyam_superset_pg_password          = get_env("TF_VAR_divyam_superset_pg_password", "")
      divyam_jwt_secret_key                = get_env("TF_VAR_divyam_jwt_secret_key", "")
      divyam_provider_keys_encryption_key  = get_env("TF_VAR_divyam_provider_keys_encryption_key", "")
      divyam_openai_billing_admin_api_key  = get_env("TF_VAR_divyam_openai_billing_admin_api_key", "")
      # User provided secrets. No default or auto-generation in the secrets module.
      divyam_superset_password     = get_env("TF_VAR_divyam_superset_password")
      divyam_router_admin_password = get_env("TF_VAR_divyam_router_admin_password")
      divyam_deployment_id         = get_env("TF_VAR_divyam_deployment_id")
      divyam_deployment_api_key    = get_env("TF_VAR_divyam_deployment_api_key")
    },
    # Azure only: Artifactory Docker auth for container registry. Omit for GCP.
    # Env var holds a file path. Read its contents so the secret value is stored in the secret manager.
    local.cloud_provider == "azure" ? { divyam_artifactory_docker_auth = file(get_env("TF_VAR_divyam_artifactory_docker_auth")) } : {}
  )
}
