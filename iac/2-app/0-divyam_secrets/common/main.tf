# Cloud-agnostic secrets map. Consumed by azure and gcp modules.
# Single variable "input" so callers pass one object (no repetition in Azure/GCP).

locals {
  env   = coalesce(var.environment, "dev")
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
  # coalesce(null, "") fails in Terraform; use conditional so empty string is valid default
  clickhouse_password           = var.input.divyam_clickhouse_password != null ? var.input.divyam_clickhouse_password : ""
  openai_key                    = var.input.divyam_openai_billing_admin_api_key != null ? var.input.divyam_openai_billing_admin_api_key : ""
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
    } : {}
  )
}
