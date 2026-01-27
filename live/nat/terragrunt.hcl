#----------------------------------------------
# NAT Module (Multi-Cloud)
# GCP: nat | Azure: nat | AWS: nat_gateway
#----------------------------------------------

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "provider" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/provider.hcl"
  expose = true
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/nat"
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_name      = ""
    network_self_link = ""
    vnet_id           = ""
    subnet_ids        = {}
  }
}

locals {
  module_config_keys = {
    gcp   = "nat"
    azure = "nat"
    aws   = "nat_gateway"
  }

  config_key = local.module_config_keys[include.root.locals.cloud_provider]

  merged_inputs = merge(
    try(include.root.locals.install_config.common_vars, {}),
    try(include.root.locals.install_config[local.config_key], {})
  )

  enabled = try(local.merged_inputs.enabled, true)
}

inputs = merge(
  local.merged_inputs,
  include.root.locals.cloud_provider == "azure" ? {
    subnet_ids   = dependency.network.outputs.subnet_ids
    network_name = null
  } : {
    subnet_ids   = null
    network_name = dependency.network.outputs.network_name
  }
)

skip = !local.enabled
