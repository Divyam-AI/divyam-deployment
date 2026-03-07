include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

include "secrets" {
  path   = "../common/secrets_input.hcl"
  expose = true
}

terraform {
  source = "./"
}

# Terraform does not allow variables in module source; generate file with literal path.
generate "common_module" {
  path      = "common_module.tf"
  if_exists = "overwrite"
  contents  = <<EOF
module "common" {
  source = "${get_terragrunt_dir()}/../common"
  input  = var.secrets_input
}
EOF
}

dependency "tfstate_azure_blob_storage" {
  config_path  = "../../../0-foundation/2-terraform_state_blob_storage/azure"
  skip_outputs = true
}

dependency "object_storage" {
  config_path = "../../0-divyam_object_storage/azure"

  mock_outputs = {
    router_requests_logs_storage_account_connection_string = null
  }

  # Use mocks when object_storage has not been applied yet. Apply requires real outputs.
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root         = include.root.locals.merged
  secrets_cfg  = try(local.root.divyam_secrets, {})
  scope_name   = local.root.resource_scope.name
  secrets_input = merge(
    include.secrets.locals.secrets_input,
    { env = local.root.env_name }
  )
}

# Pass divyam_secrets config from defaults. secrets_input from common/secrets_input.hcl.
# Azure only: merge router_requests_logs connection string from object_storage (dependency cannot be referenced in locals).
inputs = merge(
  {
    location            = local.root.region
    environment         = local.root.env_name
    resource_group_name = local.scope_name
    key_vault_name      = try(local.secrets_cfg.store_name, "${local.root.deployment_prefix}-vault")
    create_vault        = try(local.secrets_cfg.create_vault, true)
    create_secrets      = try(local.secrets_cfg.create_secrets, true)
    secrets_input       = merge(
      local.secrets_input,
      { router_requests_logs_storage_account_connection_string = dependency.object_storage.outputs.router_requests_logs_storage_account_connection_string }
    )
    common_tags         = try(include.root.inputs.common_tags, {})
    tag_globals         = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.deployment_prefix
    }
  }
)
