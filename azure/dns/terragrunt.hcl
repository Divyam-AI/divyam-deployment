include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../dns"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "vnet" {
  config_path = "../vnet"
}

dependency "app_gw" {
  config_path = "../app_gw"
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
