include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Note: Local state because storing to azure blob store create a dependency on
# creating the blob store first which also needs the vnet for access control.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root = include.root.locals.merged
  vnet_config = {
    create        = local.root.vnet.create
    name          = local.root.vnet.name
    scope_name    = local.root.vnet.scope_name
    region        = local.root.vnet.region
    zone          = local.root.vnet.zone
    address_space = local.root.vnet.address_space
    subnets       = try(local.root.vnet.subnets, [])
    app_gw        = try(local.root.vnet.app_gw, {})
  }
}

# Pass vnet + tagging inputs (common_tags, tag_globals) like 0-resource_scope so root generate "tagging" works.
inputs = merge(
  {
    vnet = local.vnet_config
    common_tags = try(local.root.common_tags, {})
    tag_globals = {
      environment   = local.root.env_name
      resource_group = local.root.resource_scope.name
      region        = local.root.region
      org           = try(local.root.org_name, "")
    }
  }
)

exclude {
  if      = !local.root.vnet.create
  actions = ["all"]
}