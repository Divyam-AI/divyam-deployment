include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
  expose = true
}

# Use Terraform in this directory (project creation).
terraform {
  source = "."
}

# Use local state; project is needed before GCS bucket for state (same chicken-egg as Azure).
remote_state {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}

locals {
  root = include.root.locals.merged
  # Map values/* (resource_scope + GCP defaults) to Terraform inputs; create = false uses data source only
  inputs = {
    resource_group_name = coalesce(try(local.root.project_id, null), local.root.resource_scope.name)
    org_id              = try(local.root.org_id, "")
    folder_id           = try(local.root.folder_id, "")
    billing_account     = try(local.root.billing_account, "")
    environment         = local.root.env_name
    labels              = try(local.root.common_tags, {})
    create              = local.root.resource_scope.create
  }
}

inputs = local.inputs
