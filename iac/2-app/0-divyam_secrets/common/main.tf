# Cloud-agnostic secrets map. Consumed by azure and gcp modules.
# Single variable "input" so callers pass one object (no repetition in Azure/GCP).

locals {
  env          = coalesce(var.environment, "dev")
  db_user_name = coalesce(var.input.divyam_db_user_name, "divyam-${local.env}")
}

# Optional: generate random passwords when not provided (null or empty string from env)
resource "random_password" "random_superset_pg_password" {
  count   = (var.input.divyam_superset_pg_password == null || var.input.divyam_superset_pg_password == "") ? 1 : 0
  length  = 16
  special = true
}

resource "random_password" "random_superset_pg_superset_password" {
  count   = (var.input.divyam_superset_password == null || var.input.divyam_superset_password == "") ? 1 : 0
  length  = 16
  special = true
}

resource "random_password" "random_db_root_password" {
  count   = (var.input.divyam_db_root_password == null || var.input.divyam_db_root_password == "") ? 1 : 0
  length  = 16
  special = true
}

locals {
  superset_pg_password          = (var.input.divyam_superset_pg_password != null && var.input.divyam_superset_pg_password != "") ? var.input.divyam_superset_pg_password : random_password.random_superset_pg_password[0].result
  superset_pg_superset_password = (var.input.divyam_superset_password != null && var.input.divyam_superset_password != "") ? var.input.divyam_superset_password : random_password.random_superset_pg_superset_password[0].result
  divyam_db_root_password       = (var.input.divyam_db_root_password != null && var.input.divyam_db_root_password != "") ? var.input.divyam_db_root_password : random_password.random_db_root_password[0].result
  clickhouse_user               = coalesce(var.input.divyam_clickhouse_user_name, "default")
  # coalesce(null, "") fails in Terraform, so use a conditional that makes the empty string a valid default
  clickhouse_password = var.input.divyam_clickhouse_password != null ? var.input.divyam_clickhouse_password : ""
  openai_key          = var.input.divyam_openai_billing_admin_api_key != null ? var.input.divyam_openai_billing_admin_api_key : ""
}

# Evalm8 secret values, gated by evalm8_enabled.
# Each key is taken from its TF_VAR_* input when the user sets one, with a random fallback for a sandbox.
# All nine evalm8 vault keys, created only when the evalm8 stack is in scope.
# The random fallbacks for the encrypt and jwt keys are at least 32 chars. The encryption key is exactly 64 hex chars for AES-256.
resource "random_password" "evalm8_lakefs_access_key_id" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 20
  special = false
}

resource "random_password" "evalm8_lakefs_secret_access_key" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 40
  special = false
}

resource "random_password" "evalm8_lakefs_auth_encrypt_key" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "evalm8_argilla_api_key" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "evalm8_argilla_auth_secret_key" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "evalm8_argilla_default_user_password" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 24
  special = true
}

resource "random_password" "evalm8_jwt_secret" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 48
  special = false
}

# Exactly 64 hex chars for an AES-256 key. random_id renders byte_length 32 as 64 hex digits.
resource "random_id" "evalm8_encryption_key" {
  count       = var.input.evalm8_enabled ? 1 : 0
  byte_length = 32
}

# Initial admin password for the evalm8 bootstrap owner account.
# The evalm8-server bootstrap that consumes this is not wired yet, see issue #66.
resource "random_password" "evalm8_admin_password" {
  count   = var.input.evalm8_enabled ? 1 : 0
  length  = 24
  special = true
}

locals {
  evalm8_secrets = var.input.evalm8_enabled ? {
    "divyam-lakefs-access-key-id"          = (var.input.divyam_lakefs_access_key_id != null && var.input.divyam_lakefs_access_key_id != "") ? var.input.divyam_lakefs_access_key_id : random_password.evalm8_lakefs_access_key_id[0].result
    "divyam-lakefs-secret-access-key"      = (var.input.divyam_lakefs_secret_access_key != null && var.input.divyam_lakefs_secret_access_key != "") ? var.input.divyam_lakefs_secret_access_key : random_password.evalm8_lakefs_secret_access_key[0].result
    "divyam-lakefs-auth-encrypt-key"       = (var.input.divyam_lakefs_auth_encrypt_key != null && var.input.divyam_lakefs_auth_encrypt_key != "") ? var.input.divyam_lakefs_auth_encrypt_key : random_password.evalm8_lakefs_auth_encrypt_key[0].result
    "divyam-argilla-api-key"               = (var.input.divyam_argilla_api_key != null && var.input.divyam_argilla_api_key != "") ? var.input.divyam_argilla_api_key : random_password.evalm8_argilla_api_key[0].result
    "divyam-argilla-auth-secret-key"       = (var.input.divyam_argilla_auth_secret_key != null && var.input.divyam_argilla_auth_secret_key != "") ? var.input.divyam_argilla_auth_secret_key : random_password.evalm8_argilla_auth_secret_key[0].result
    "divyam-argilla-default-user-password" = (var.input.divyam_argilla_default_user_password != null && var.input.divyam_argilla_default_user_password != "") ? var.input.divyam_argilla_default_user_password : random_password.evalm8_argilla_default_user_password[0].result
    "divyam-evalm8-jwt-secret"             = (var.input.divyam_evalm8_jwt_secret != null && var.input.divyam_evalm8_jwt_secret != "") ? var.input.divyam_evalm8_jwt_secret : random_password.evalm8_jwt_secret[0].result
    "divyam-evalm8-encryption-key"         = (var.input.divyam_evalm8_encryption_key != null && var.input.divyam_evalm8_encryption_key != "") ? var.input.divyam_evalm8_encryption_key : random_id.evalm8_encryption_key[0].hex
    "divyam-evalm8-admin-password"         = (var.input.divyam_evalm8_admin_password != null && var.input.divyam_evalm8_admin_password != "") ? var.input.divyam_evalm8_admin_password : random_password.evalm8_admin_password[0].result
  } : {}
}

locals {
  secrets = merge(
    {
      "divyam-db-root-password"              = local.divyam_db_root_password
      "divyam-db-password"                   = var.input.divyam_db_password
      "divyam-db-user-name"                  = local.db_user_name
      "divyam-analytics-db-user-name"        = local.clickhouse_user
      "divyam-analytics-db-password"         = local.clickhouse_password
      "divyam-superset-pg-password"          = local.superset_pg_password
      "divyam-superset-pg-superset-password" = local.superset_pg_superset_password
      "divyam-jwt-secret-key"                = var.input.divyam_jwt_secret_key
      "divyam-provider-keys-encryption-key"  = var.input.divyam_provider_keys_encryption_key
      "divyam-openai-billing-admin-api-key"  = local.openai_key
      "divyam-artifactory-docker-auth"       = var.input.divyam_artifactory_docker_auth
      "divyam-router-admin-password"         = var.input.divyam_router_admin_password
      "divyam-deployment-id"                 = var.input.divyam_deployment_id
      "divyam-deployment-api-key"            = var.input.divyam_deployment_api_key

      "divyam-billing-secrets" = <<-EOT
      llm_keys:
        OpenAI:
          billing_api_key: "${local.openai_key}"
      clickhouse:
        user: "${local.clickhouse_user}"
        password: "${local.clickhouse_password}"
      mysql:
        user: "${local.db_user_name}"
        password: "${var.input.divyam_db_password}"
    EOT
    },
    # Azure only: Kafka to Blob storage consumer reads this from Key Vault. Not set for GCP.
    var.input.router_requests_logs_storage_account_connection_string != null ? {
      "router-requests-logs-storage-account-connection-string" = var.input.router_requests_logs_storage_account_connection_string
    } : {},
    # Evalm8 vault keys, TF-generated. Empty unless the evalm8 stack is in scope.
    local.evalm8_secrets
  )
}
