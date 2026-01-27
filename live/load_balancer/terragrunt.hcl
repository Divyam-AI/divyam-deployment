#----------------------------------------------
# Load Balancer Module (Multi-Cloud)
# GCP: elb | Azure: app_gw | AWS: alb
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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/load_balancer"
}

dependency "bootstrap" {
  config_path  = "../_bootstrap"
  skip_outputs = true

  mock_outputs = {
    enabled_api_services = []
  }
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_name      = ""
    network_self_link = ""
    subnet_self_link  = ""
    vnet_id           = ""
    subnet_ids        = {}
  }
}

locals {
  module_config_keys = {
    gcp   = "elb"
    azure = "app_gw"
    aws   = "alb"
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
    vnet_id           = dependency.network.outputs.vnet_id
    subnet_ids        = dependency.network.outputs.subnet_ids
    network_self_link = null
  } : {
    vnet_id           = null
    subnet_ids        = null
    network_self_link = dependency.network.outputs.network_self_link
  }
)

skip = !local.enabled
