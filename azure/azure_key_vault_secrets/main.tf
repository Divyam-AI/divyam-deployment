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
  superset_pg_password          = var.divyam_superset_pg_password != null ? var.divyam_superset_pg_password : random_password.random_superset_pg_password.result
  superset_pg_superset_password = var.divyam_superset_pg_superset_password != null ? var.divyam_superset_pg_superset_password : random_password.random_superset_pg_superset_password.result
  divyam_db_root_password= var.divyam_db_root_password != null ? var.divyam_db_root_password : random_password.random_db_root_password.result
}

resource "azurerm_key_vault_secret" "db_root_password" {
  name         = "divyam-db-root-password"
  value        = local.divyam_db_root_password
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "db_user_password" {
  name         = "divyam-db-user-name-password-secret-key"
  value        = "${var.divyam_db_user_name}:${var.divyam_db_password}"
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "divyam-db-password"
  value        = var.divyam_db_password
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "db_user_name" {
  name         = "divyam-db-user-name"
  value        = var.divyam_db_user_name
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "clickhouse_password" {
  name         = "divyam-clickhouse-password"
  value        = var.divyam_clickhouse_password
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "superset_pg_password" {
  name         = "divyam-superset-pg-password"
  value        = local.superset_pg_password
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "superset_pg_superset_password" {
  name         = "divyam-superset-pg-superset-password"
  value        = local.superset_pg_superset_password
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "clickhouse_user" {
  name         = "divyam-clickhouse-user-name"
  value        = var.divyam_clickhouse_user_name
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "billing_secrets" {
  name         = "divyam-billing-secrets"
  value        = <<-EOT
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
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "jwt_secret_key" {
  name         = "divyam-jwt-secret-key"
  value        = var.divyam_jwt_secret_key
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "provider_keys_encryption_key" {
  name         = "divyam-provider-keys-encryption-key"
  value        = var.divyam_provider_keys_encryption_key
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "openai_billing_admin_api_key" {
  name         = "divyam-openai-billing-admin-api-key"
  value        = var.divyam_openai_billing_admin_api_key
  key_vault_id = var.azure_key_vault_id
}

resource "azurerm_key_vault_secret" "divyam_gar_sa_key" {
  name         = "divyam-gar-sa-key"
  key_vault_id = var.azure_key_vault_id
  value        = var.divyam_gar_sa_key
}

