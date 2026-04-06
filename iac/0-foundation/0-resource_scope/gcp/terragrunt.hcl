include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Use Terraform in this directory (project creation).
terraform {
  source = "."
}

# Use local state; project is needed before GCS bucket for state (same chicken-egg as Azure).
remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    path = include.root.locals.local_state_file
  }
}

locals {
  root = include.root.locals.merged
  # Map values/* (resource_scope + GCP defaults) to Terraform inputs; create = false uses data source only
  inputs = {
    resource_scope = local.root.resource_scope
    org_id         = try(local.root.resource_scope.org_id, try(local.root.org_id, ""))
    folder_id      = try(local.root.folder_id, "")
    billing_account = try(local.root.resource_scope.billing_account, "")
    env_name       = local.root.env_name
    common_tags    = try(local.root.common_tags, {})
    tag_globals    = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.resource_scope.name
    }
  }
}

inputs = local.inputs
