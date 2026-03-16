# Common module: builds secrets map and optional random passwords. Invoked with merged_secrets_input
# (connection string from Azure data source when router_requests_logs_storage_account_name is set).
# Path to common is passed as common_module_source from Terragrunt so it works in cache.

module "common" {
  source      = var.common_module_source
  input       = local.merged_secrets_input
  environment = var.environment
}
