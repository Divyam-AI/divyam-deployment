include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../azure_key_vault_secrets"
}
# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.azure_key_vault_secrets
  )
}

inputs = merge(local.merged_inputs, {
  azure_key_vault_id = dependency.azure_key_vault.outputs.azure_key_vault_id
})

skip = !local.merged_inputs.enabled