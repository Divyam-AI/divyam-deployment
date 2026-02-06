include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../tfstate_azure_blob_storage"
}

dependency "vnet" {
  config_path = "../vnet"

  mock_outputs = {
    subnet_ids = {}
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "apply"]
}

# Note: Local state because storing to azure blob store cannot happen until this
# storage account is created.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.tfstate_azure_blob_storage,
  )
}

inputs = merge(local.merged_inputs, {
  storage_account_name = include.root.locals.tfstate_storage_account_name
  subnet_ids           = dependency.vnet.outputs.subnet_ids
})

skip = !local.merged_inputs.enabled
