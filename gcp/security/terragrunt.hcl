include "root" {
  path   = find_in_parent_folders("root.hcl", "gcp/root.hcl")
  expose = true
}

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../security"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.security
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled