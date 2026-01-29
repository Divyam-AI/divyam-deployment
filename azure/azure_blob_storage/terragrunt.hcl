include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../azure_blob_storage"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../vnet"

  mock_outputs = {
    subnet_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.azure_blob_storage
  )
}

inputs = merge(local.merged_inputs, {
  storage_account_name = include.root.locals.tfstate_storage_account_name
  subnet_ids           = dependency.vnet.outputs.subnet_ids
})

skip = !local.merged_inputs.enabled
