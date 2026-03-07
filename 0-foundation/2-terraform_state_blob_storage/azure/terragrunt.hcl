include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/azure"

  mock_outputs = {
    subnet_ids = {}
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "apply"]
}

# Note: Local state because storing to azure blob store cannot happen until this
# storage account is created.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root = include.root.locals.merged
  inputs = merge(
    {
      resource_group_name     = local.root.resource_scope.name
      location                = local.root.region
      environment             = local.root.env_name
      tag_globals             = try(include.root.inputs.tag_globals, {})
      tag_context = {
        resource_name = include.root.locals.merged.tfstate.bucket_name
      }
      create                  = local.root.tfstate.create
      storage_account_name    = include.root.locals.merged.tfstate.bucket_name
      storage_container_name  = include.root.locals.merged.tfstate.bucket_name
    }
  )
}

# dependency is only available at top level; merge its outputs into inputs here
inputs = merge(
  local.inputs,
  {
    subnet_ids = dependency.vnet.outputs.subnet_ids
  }
)
