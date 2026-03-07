include "root" {
  path   = find_in_parent_folders("root.hcl")
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

# Pass vnet + tagging inputs (common_tags, tag_globals, tag_context) like 0-resource_scope so root generate "tagging" works.
inputs = merge(
  {
    vnet        = local.vnet_config
    common_tags = try(local.root.common_tags, {})
    tag_globals = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.vnet.name
    }
  }
)
