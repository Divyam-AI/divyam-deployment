include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../dns"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../vnet"

  mock_outputs = {
    vnet_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "app_gw" {
  config_path = "../app_gw"

  mock_outputs = {
    app_gateway_name = "mock-appgw"
    app_gateway_id   = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/applicationGateways/mock"
    load_balancer_ip = "10.0.0.1"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.dns,
  )
}

inputs = merge(local.merged_inputs, {
  vnet_id           = dependency.vnet.outputs.vnet_id
  app_gateway_name  = dependency.app_gw.outputs.app_gateway_name
  app_gateway_id    = dependency.app_gw.outputs.app_gateway_id
  app_gateway_lb_ip = dependency.app_gw.outputs.load_balancer_ip
})

skip = !local.merged_inputs.enabled
