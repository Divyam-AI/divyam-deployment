#----------------------------------------------
# Kubernetes Module (Multi-Cloud)
# GCP: gke | Azure: aks | AWS: eks
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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/kubernetes"
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_name      = "mock-network"
    network_self_link = "mock-self-link"
    subnet_name       = "mock-subnet"
    subnet_self_link  = "mock-subnet-link"
    vnet_id           = "mock-vnet-id"
    subnet_ids        = {}
    subnet_names      = []
    subnet_prefixes   = []
  }
}

dependency "bootstrap" {
  config_path  = "../_bootstrap"
  skip_outputs = true

  mock_outputs = {
    enabled_api_services = []
  }
}

dependency "load_balancer" {
  config_path  = "../load_balancer"
  skip_outputs = include.root.locals.cloud_provider != "azure"

  mock_outputs = {
    app_gateway_id          = ""
    app_gateway_name        = ""
    agic_identity_id        = ""
    agic_identity_client_id = ""
  }
}

dependency "nat" {
  config_path  = "../nat"
  skip_outputs = include.root.locals.cloud_provider != "azure"

  mock_outputs = {
    nat_gateway_enabled = false
    nat_gateway_ip      = null
  }
}

locals {
  module_config_keys = {
    gcp   = "gke"
    azure = "aks"
    aws   = "eks"
  }

  config_key = local.module_config_keys[include.root.locals.cloud_provider]

  merged_inputs = merge(
    try(include.root.locals.install_config.common_vars, {}),
    try(include.root.locals.install_config.derived_vars, {}),
    try(include.root.locals.install_config[local.config_key], {})
  )

  enabled = try(local.merged_inputs.enabled, true)
}

inputs = merge(
  local.merged_inputs,
  include.root.locals.cloud_provider == "azure" ? {
    vnet_id          = dependency.network.outputs.vnet_id
    subnet_ids       = dependency.network.outputs.subnet_ids
    subnet_names     = dependency.network.outputs.subnet_names
    subnet_prefixes  = dependency.network.outputs.subnet_prefixes
    app_gateway_name = dependency.load_balancer.outputs.app_gateway_name
    app_gateway_id   = dependency.load_balancer.outputs.app_gateway_id
    agic_identity_id = dependency.load_balancer.outputs.agic_identity_id
    agic_client_id   = dependency.load_balancer.outputs.agic_identity_client_id
    nat_gateway_ip   = dependency.nat.outputs.nat_gateway_enabled ? dependency.nat.outputs.nat_gateway_ip : null
  } : {
    network_name      = dependency.network.outputs.network_name
    network_self_link = dependency.network.outputs.network_self_link
  }
)

skip = !local.enabled
