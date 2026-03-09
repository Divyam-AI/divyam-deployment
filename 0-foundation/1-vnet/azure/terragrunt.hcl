include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "resource_scope" {
  config_path = "../../0-resource_scope/azure"
  mock_outputs = {
    resource_group_name = "mock-rg"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply"]
}

terraform {
  source = "./"
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
  root = include.root.locals.merged
  vnet_config = local.root.vnet
}

# Pass vnet + tagging inputs (common_tags, tag_globals, tag_context) like 0-resource_scope so root generate "tagging" works.
inputs = merge(
  {
    vnet        = local.vnet_config
    common_tags = try(local.root.common_tags, {})
    tag_globals = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.vnet.name
    }
  }
)