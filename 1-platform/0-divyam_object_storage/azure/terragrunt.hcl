include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "tfstate_azure_blob_storage" {
  config_path  = "../../../0-foundation/2-terraform_state_blob_storage/azure"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../../../0-foundation/1-vnet/azure"

  mock_outputs = {
    subnet_ids = {}
  }

  # Use mocks when vnet dependency has no outputs (e.g. first run before vnet is applied).
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

locals {
  root     = include.root.locals.merged
  storages = try(local.root.divyam_object_storages, [])
  # Group by storage_account_name; each distinct storage_account_name -> one account (full name from config) and container names.
  storage_accounts = length(local.storages) > 0 ? {
    for name in distinct([for s in local.storages : s.storage_account_name]) :
    name => {
      name            = [for s in local.storages : s.storage_account_name if s.storage_account_name == name][0]
      container_names = [for s in local.storages : s.container_name if s.storage_account_name == name]
      create          = length([for s in local.storages : s if s.storage_account_name == name && try(s.create, true)]) > 0
      type            = try([for s in local.storages : s.type if s.storage_account_name == name][0], null)
    }
  } : {}
  scope_name = local.root.resource_scope.name
  # Key in storage_accounts whose type is "router-requests-logs" (for backward-compat outputs).
  router_requests_logs_storage_key = try([for k, v in local.storage_accounts : k if v.type == "router-requests-logs"][0], null)
}

# Pass divyam_object_storage config from defaults + tagging (tag_globals, tag_context) like 1-vnet.
inputs = merge(
  {
    location                        = local.root.region
    environment                     = local.root.env_name
    resource_group_name             = local.scope_name
    storage_accounts                = local.storage_accounts
    router_requests_logs_storage_key = local.router_requests_logs_storage_key
    subnet_ids                      = dependency.vnet.outputs.subnet_ids
    tag_globals                     = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.deployment_prefix
    }
  }
)
