include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/azure"
  skip_outputs = true
  mock_outputs = {
    subnet_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply","destroy","show"]
}

# Note: Local state because storing to azure blob store cannot happen until this
# storage account is created.
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    path = include.root.locals.local_state_file
  }
}

locals {
  root = include.root.locals.merged
  inputs = merge(
    {
      resource_group_name     = local.root.resource_scope.name
      location                = local.root.region
      environment             = local.root.env_name
      common_tags             = try(local.root.common_tags, {})
      tag_globals             = try(include.root.inputs.tag_globals, {})
      tag_context = {
        resource_name = include.root.locals.merged.tfstate.bucket_name
      }
      create                  = local.root.tfstate.create && !try(local.root.tfstate.local_state, false)
      local_state             = try(local.root.tfstate.local_state, false)
      storage_account_name    = include.root.locals.merged.tfstate.bucket_name
      storage_container_name  = include.root.locals.merged.tfstate.bucket_name
      vnet_name               = try(local.root.vnet.name, "")
      vnet_resource_group_name = try(local.root.vnet.scope_name, "")
    }
  )
}

# dependency is only available at top level; pass its (mock) outputs here.
inputs = merge(
  local.inputs,
  {
    subnet_ids = dependency.vnet.outputs.subnet_ids
  }
)
