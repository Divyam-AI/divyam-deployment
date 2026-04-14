include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

locals {
  root     = include.root.locals.merged
  # Subnet names from defaults.hcl: vnet.subnet and vnet.app_gw_subnet are single objects with .name.
  vnet_subnet_names = [local.root.vnet.subnet.name]
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

# Pass divyam_object_storage config from defaults + tagging. Subnet IDs are looked up in Azure using vnet.name + vnet.subnet.name and vnet.app_gw_subnet.name.
inputs = merge(
  {
    location                         = local.root.region
    environment                      = local.root.env_name
    resource_group_name              = local.scope_name
    storage_accounts                 = local.storage_accounts
    router_requests_logs_storage_key = local.router_requests_logs_storage_key
    vnet_name                        = local.root.vnet.name
    vnet_resource_group_name        = local.root.vnet.scope_name
    vnet_subnet_names                = local.vnet_subnet_names
    common_tags                      = try(local.root.common_tags, {})
    tag_globals                      = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.deployment_prefix
    }
  }
)
