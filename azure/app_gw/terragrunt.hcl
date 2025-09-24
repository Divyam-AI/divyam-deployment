include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../app_gw"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "vnet" {
  config_path = "../vnet"
}

dependency "tls_certs" {
  config_path = "../tls_certs"
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.app_gw,
  )
}

inputs = merge(local.merged_inputs, {
  vnet_name = dependency.vnet.outputs.vnet_name
  vnet_id               = dependency.vnet.outputs.vnet_id
  subnet_ids            = dependency.vnet.outputs.subnet_ids
  subnet_names          = dependency.vnet.outputs.subnet_names
  subnet_prefixes       = dependency.vnet.outputs.subnet_prefixes
  tls_enabled           = dependency.tls_certs.outputs.tls_enabled
  azure_key_vault_id    = dependency.azure_key_vault.outputs.azure_key_vault_id
  certificate_secret_id = dependency.tls_certs.outputs.tls_enabled ? dependency.tls_certs.outputs.certificate_secret_id : null
})

skip = !local.merged_inputs.enabled
