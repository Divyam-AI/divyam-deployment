include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../app_gw"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../vnet"

  mock_outputs = {
    vnet_name                = "mock-vnet"
    vnet_resource_group_name = "mock-rg"
    vnet_id                  = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock"
    subnet_ids               = {}
    subnet_names             = []
    subnet_prefixes          = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "tls_certs" {
  config_path = "../tls_certs"

  mock_outputs = {
    tls_enabled           = false
    certificate_secret_id = null
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"

  mock_outputs = {
    azure_key_vault_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.app_gw,
  )
}

inputs = merge(local.merged_inputs, {
  vnet_name = dependency.vnet.outputs.vnet_name
  vnet_resource_group_name = dependency.vnet.outputs.vnet_resource_group_name
  vnet_id               = dependency.vnet.outputs.vnet_id
  subnet_ids            = dependency.vnet.outputs.subnet_ids
  subnet_names          = dependency.vnet.outputs.subnet_names
  subnet_prefixes       = dependency.vnet.outputs.subnet_prefixes
  tls_enabled           = dependency.tls_certs.outputs.tls_enabled
  azure_key_vault_id    = dependency.azure_key_vault.outputs.azure_key_vault_id
  certificate_secret_id = dependency.tls_certs.outputs.tls_enabled ? dependency.tls_certs.outputs.certificate_secret_id : null
})

skip = !local.merged_inputs.enabled
