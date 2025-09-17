include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../resource_group"
}

# Use local storage because resource group is needed for Azure storage account.
# Using the same storage account for creating the resource group is a circular
# dependency.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.resource_group
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled