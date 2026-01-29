include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../azure_key_vault"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../tfstate_azure_blob_storage"
  skip_outputs = true
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.azure_key_vault,
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled
