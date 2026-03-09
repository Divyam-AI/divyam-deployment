include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "vnet" {
  config_path = "../../1-vnet/gcp"

  mock_outputs = {
    subnet_ids = {}
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "apply"]
}

# Note: Local state because storing to GCS cannot happen until this bucket is created.
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root   = include.root.locals.merged
  inputs = merge(
    {
      project_id   = local.root.resource_scope.name
      location     = local.root.region
      environment  = local.root.env_name
      common_tags   = try(local.root.common_tags, {})
      tag_globals  = try(include.root.inputs.tag_globals, {})
      tag_context = {
        resource_name = include.root.locals.merged.tfstate.bucket_name
      }
      create      = local.root.tfstate.create
      bucket_name = include.root.locals.merged.tfstate.bucket_name
    }
  )
}

inputs = local.inputs
