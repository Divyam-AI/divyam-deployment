include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/azure"

  mock_outputs = {
    subnet_id        = ""
    app_gw_subnet_id = ""
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Local state like 1-vnet; NAT depends on VNet and can run before blob storage.
remote_state {
  backend = "local"
  config = {
    path = include.root.locals.local_state_file
  }
}

locals {
  root       = include.root.locals.merged
  nat_config = try(local.root.nat, { create = false, resource_name_prefix = "divyam" })
}

inputs = merge(
  {
    location             = local.root.region
    common_tags          = try(local.root.common_tags, {})
    resource_group_name  = local.root.resource_scope.name
    resource_name_prefix = try(local.nat_config.resource_name_prefix, "divyam")
    create               = try(local.nat_config.create, false)
    # Build subnet_ids map from 1-vnet outputs for NAT gateway association (dependency only available in inputs).
    subnet_ids = {
      subnet        = dependency.vnet.outputs.subnet_id
      app_gw_subnet = dependency.vnet.outputs.app_gw_subnet_id
    }
    tag_globals          = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = "${try(local.nat_config.resource_name_prefix, "divyam")}-nat-gateway"
    }
  }
)
