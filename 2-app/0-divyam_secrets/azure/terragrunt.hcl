include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "secrets" {
  path   = "../common/secrets_input.hcl"
  expose = true
}

terraform {
  source = "./"
}

# Terraform does not allow variables in module source; common module path and merged input (with connection string from Azure) in common_module.tf.
locals {
  root         = include.root.locals.merged
  secrets_cfg  = try(local.root.divyam_secrets, {})
  scope_name   = local.root.resource_scope.name
  secrets_input = include.secrets.locals.secrets_input
  # Router-requests-logs storage account name from defaults.hcl. Fetched from Azure in Terraform via data source.
  router_logs_sa_name = try(one([for s in local.root.divyam_object_storages : s.storage_account_name if s.type == "router-requests-logs"]), null)
}

# Pass divyam_secrets config from defaults. Connection string is fetched from Azure (cloud) in Terraform via data source using router_logs_sa_name.
inputs = merge(
  {
    location                                  = local.root.region
    environment                               = local.root.env_name
    resource_group_name                       = local.scope_name
    key_vault_name                            = try(local.secrets_cfg.store_name, "${local.root.deployment_prefix}-vault")
    create_vault                              = try(local.secrets_cfg.create_vault, true)
    create_secrets                            = try(local.secrets_cfg.create_secrets, true)
    secrets_input                             = local.secrets_input
    router_requests_logs_storage_account_name = local.router_logs_sa_name
    common_module_source                      = "${get_terragrunt_dir()}/../common"
    common_tags                               = try(include.root.inputs.common_tags, {})
    tag_globals                               = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.deployment_prefix
    }
  }
)
