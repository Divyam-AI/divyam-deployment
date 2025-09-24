resource "random_password" "random_superset_pg_password" {
  length  = 16
  special = true
}

resource "random_password" "random_superset_pg_superset_password" {
  length  = 16
  special = true
}

resource "random_password" "random_db_root_password" {
  length  = 16
  special = true
}

locals {
  # Convert the values to terraform templates.
  common_tags = {
    for key, value in var.common_tags :
    key => replace(value, "/@\\{([^}]+)\\}/", "$${$1}")
  }

  superset_pg_password          = var.divyam_superset_pg_password != null ? var.divyam_superset_pg_password : random_password.random_superset_pg_password.result
  superset_pg_superset_password = var.divyam_superset_pg_superset_password != null ? var.divyam_superset_pg_superset_password : random_password.random_superset_pg_superset_password.result
  divyam_db_root_password       = var.divyam_db_root_password != null ? var.divyam_db_root_password : random_password.random_db_root_password.result

  secrets = {
    "divyam-db-root-password"              = local.divyam_db_root_password
    "divyam-db-user-name-password-secret"  = "${var.divyam_db_user_name}:${var.divyam_db_password}"
    "divyam-db-password"                   = var.divyam_db_password
    "divyam-db-user-name"                  = var.divyam_db_user_name
    "divyam-clickhouse-password"           = var.divyam_clickhouse_password
    "divyam-superset-pg-password"          = local.superset_pg_password
    "divyam-superset-pg-superset-password" = local.superset_pg_superset_password
    "divyam-clickhouse-user-name"          = var.divyam_clickhouse_user_name
    "divyam-jwt-secret-key"                = var.divyam_jwt_secret_key
    "divyam-provider-keys-encryption-key"  = var.divyam_provider_keys_encryption_key
    "divyam-openai-billing-admin-api-key"  = var.divyam_openai_billing_admin_api_key
    "divyam-gar-sa-key"                    = var.divyam_gar_sa_key

    # Complex/big value still works too
    "divyam-billing-secrets" = <<-EOT
      llm_keys:
        OpenAI:
          billing_api_key: "${var.divyam_openai_billing_admin_api_key}"
      clickhouse:
        user: "${var.divyam_clickhouse_user_name}"
        password: "${var.divyam_clickhouse_password}"
      mysql:
        user: "${var.divyam_db_user_name}"
        password: "${var.divyam_db_password}"
    EOT
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each     = local.secrets
  name         = each.key
  value        = each.value
  key_vault_id = var.azure_key_vault_id
  tags = {
    for key, value in local.common_tags :
    key => templatestring(value, {
      resource_name  = each.key
      location       = var.location
      resource_group = var.resource_group_name
      environment    = var.environment
    })
  }
}
