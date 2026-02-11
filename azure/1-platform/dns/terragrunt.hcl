include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../dns"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../../0-foundation/vnet"

  mock_outputs = {
    vnet_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock"
  }
}

dependency "app_gw" {
  config_path = "../app_gw"

  mock_outputs = {
    load_balancer_ip = "0.0.0.0"
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.dns,
  )
}

inputs = merge(local.merged_inputs, {
  vnet_id           = dependency.vnet.outputs.vnet_id
  app_gateway_lb_ip = dependency.app_gw.outputs.load_balancer_ip
})

skip = !local.merged_inputs.enabled
