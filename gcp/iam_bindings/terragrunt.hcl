include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../iam_bindings"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.iam_bindings
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled