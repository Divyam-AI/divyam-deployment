include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Run 0-resource_scope before this module. Use dependencies (not dependency) so import/plan work without reading resource_scope outputs.
dependencies {
  paths = ["../../0-resource_scope/gcp"]
}

terraform {
  source = "./"
}

# Local state; GCP VPC may be created before state bucket (same chicken-egg as Azure vnet).
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
