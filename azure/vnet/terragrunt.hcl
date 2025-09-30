include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../vnet"
}

# Note: Local state because storing to azure blob store create a dependency on
# creating the blob store first which also needs the vnet for access control.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.vnet
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled