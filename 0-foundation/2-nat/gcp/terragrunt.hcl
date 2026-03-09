include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/gcp"

  mock_outputs = {
    vnet_name           = "default"
    vnet_resource_group_name = ""
    subnet_id           = ""
    subnet_prefix       = "10.0.0.0/24"
    app_gw_subnet_id   = ""
    app_gw_subnet_prefix = "10.0.8.0/27"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

# Local state like 1-vnet; NAT depends on VPC and can run before state bucket.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root       = include.root.locals.merged
  nat_config = try(local.root.nat, { create = true, router_name = "nat-router", nat_config_name = "nat-config" })
  project_id = local.root.resource_scope.name
  region     = local.root.region
}

inputs = merge(
  {
    project_id       = local.project_id
    region          = local.region
    network         = dependency.vnet.outputs.vnet_name
    router_name     = try(local.nat_config.router_name, "${local.root.deployment_prefix}-nat-router")
    nat_config_name = try(local.nat_config.nat_config_name, "${local.root.deployment_prefix}-nat-config")
    # Build from 1-vnet outputs (dependency only available in inputs, not in locals).
    nat_subnetworks = [
      {
        name  = dependency.vnet.outputs.subnet_id
        cidrs = [dependency.vnet.outputs.subnet_prefix]
      },
      {
        name  = dependency.vnet.outputs.app_gw_subnet_id
        cidrs = [dependency.vnet.outputs.app_gw_subnet_prefix]
      }
    ]
    enabled = try(local.nat_config.create, true)

    common_tags  = try(local.root.common_tags, {})
    tag_globals  = try(include.root.inputs.tag_globals, {})
    tag_context  = {}
  }
)
