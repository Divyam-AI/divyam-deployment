include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Local state like 1-vnet; NAT depends on VPC and can run before state bucket.
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
  root       = include.root.locals.merged
  nat_config = try(local.root.nat, { create = true, router_name = "nat-router", nat_config_name = "nat-config" })
  project_id = local.root.resource_scope.name
  region     = local.root.region
  # Build mock subnet self links from values (same source as 1-vnet) so plan validates when dependency uses mocks
  vnet       = try(local.root.vnet, {})
  subnet_name = try(local.vnet.subnet.name, "default")
  app_gw_subnet_name = try(local.vnet.app_gw_subnet.name, "proxy-only-subnet")
  subnet_prefix_mock     = try(local.vnet.subnet.subnet_ip, "10.0.0.0/24")
  app_gw_subnet_prefix_mock = try(local.vnet.app_gw_subnet.subnet_ip, "10.0.8.0/27")
}

dependency "vnet" {
  config_path = "../../1-vnet/gcp"

  mock_outputs = {
    vnet_name                = try(local.root.vnet.name, "default")
    vnet_id                  = "https://www.googleapis.com/compute/v1/projects/${local.project_id}/global/networks/${try(local.root.vnet.name, "default")}"
    vnet_resource_group_name = local.project_id
    # NAT subnetwork block requires non-empty name (self link); build from values so plan validates with mocks
    subnet_id                = "https://www.googleapis.com/compute/v1/projects/${local.project_id}/regions/${local.region}/subnetworks/${local.subnet_name}"
    subnet_prefix            = local.subnet_prefix_mock
    app_gw_subnet_id         = "https://www.googleapis.com/compute/v1/projects/${local.project_id}/regions/${local.region}/subnetworks/${local.app_gw_subnet_name}"
    app_gw_subnet_prefix     = local.app_gw_subnet_prefix_mock
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

inputs = merge(
  {
    project_id       = local.project_id
    region          = local.region
    # Use vnet_id (self link) so config matches state and router is not replaced; vnet_name would differ from state.
    network         = dependency.vnet.outputs.vnet_id
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
