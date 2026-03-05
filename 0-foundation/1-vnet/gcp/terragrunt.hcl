include "root" {
  path   = find_in_parent_folders("terragrunt.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Local state; GCP VPC may be created before state bucket (same chicken-egg as Azure vnet).
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root = include.root.locals.merged
  # Same shape as Azure; app_gw_subnet omitted/empty for GCP (ignored in module).
  vnet_config = {
    create        = local.root.vnet.create
    name          = local.root.vnet.name
    scope_name    = local.root.vnet.scope_name
    region        = local.root.vnet.region
    zone          = local.root.vnet.zone
    address_space = local.root.vnet.address_space
    subnets       = try(local.root.vnet.subnets, [])
    app_gw_subnet = [] # Not used on GCP; ignore app-gw_subnets
  }
}

inputs = merge(
  {
    vnet = local.vnet_config
    common_tags = try(local.root.common_tags, {})
    tag_globals = {
      environment    = local.root.env_name
      resource_group = local.root.resource_scope.name
      region         = local.root.region
      org            = try(local.root.org_name, "")
    }
  }
)

exclude {
  if      = !local.root.vnet.create
  actions = ["all"]
}
