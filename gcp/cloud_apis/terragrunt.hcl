include "root" {
  path   = find_in_parent_folders("root.hcl", "gcp/root.hcl")
  expose = true
}

terraform {
  source = "../cloud_apis"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.cloud_apis
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled