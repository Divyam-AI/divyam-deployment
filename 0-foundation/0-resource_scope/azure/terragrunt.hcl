include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
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
  root = include.root.locals.merged
  # Map values/* (resource_scope) to Terraform inputs; create = false uses data source only
  inputs = {
    resource_scope = local.root.resource_scope
    region      = local.root.region
    zone        = try(local.root.zone, "")
    env_name    = local.root.env_name
    common_tags = try(local.root.common_tags, {})
    tag_globals = try(include.root.inputs.tag_globals, {})
    tag_context = {
      resource_name = local.root.resource_scope.name
    }
  }
}

inputs = local.inputs