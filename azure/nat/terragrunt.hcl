include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../nat"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "vnet" {
  config_path = "../vnet"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.nat,
  )
}

inputs = merge(local.merged_inputs, {
  subnet_ids = dependency.vnet.outputs.subnet_ids
})

skip = !local.merged_inputs.enabled
