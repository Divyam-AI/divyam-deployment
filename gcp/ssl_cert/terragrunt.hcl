include "root" {
  path   = find_in_parent_folders("root.hcl", "gcp/root.hcl")
  expose = true
}

dependency "cloud_apis" {
  config_path  = "../cloud_apis"
  skip_outputs = !include.root.locals.install_config.cloud_enabled
  mock_outputs = {
    enabled_api_services = []
  }
}

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../ssl_cert"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.ssl_cert
  )
}

inputs = local.merged_inputs

skip = !local.merged_inputs.enabled