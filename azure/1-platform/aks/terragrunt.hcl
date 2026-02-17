include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../aks"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../../0-foundation/vnet"

  mock_outputs = {
    vnet_id         = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock"
    subnet_ids      = {}
    subnet_names    = []
    subnet_prefixes = {}
  }
}

dependency "app_gw" {
  config_path = "../app_gw"

  mock_outputs = {
    app_gateway_name        = "mock-app-gateway"
    app_gateway_id          = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/applicationGateways/mock"
    agic_identity_id        = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock"
    agic_identity_client_id = "mock-agic-client-id"
    gateway_subnet_id       = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
  }
}

dependency "nat" {
  config_path = "../nat"

  mock_outputs = {
    nat_gateway_enabled = false
    nat_gateway_ip      = null
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.aks,
  )
}

inputs = merge(local.merged_inputs, {
  vnet_id          = dependency.vnet.outputs.vnet_id
  subnet_ids       = dependency.vnet.outputs.subnet_ids
  subnet_names     = dependency.vnet.outputs.subnet_names
  subnet_prefixes  = dependency.vnet.outputs.subnet_prefixes
  app_gateway_name = dependency.app_gw.outputs.app_gateway_name
  app_gateway_id   = dependency.app_gw.outputs.app_gateway_id
  nat_gateway_ip = dependency.nat.outputs.nat_gateway_enabled ? dependency.nat.outputs.nat_gateway_ip : null
  agic_identity_id = dependency.app_gw.outputs.agic_identity_id
  agic_client_id   = dependency.app_gw.outputs.agic_identity_client_id
  artifacts_path   = include.root.locals.install_config.helm_charts.artifacts_path
  exclude_charts   = include.root.locals.install_config.helm_charts.exclude_charts
  app_gateway_subnet_id = dependency.app_gw.outputs.gateway_subnet_id

})

skip = !local.merged_inputs.enabled
