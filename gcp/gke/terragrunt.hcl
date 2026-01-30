include "root" {
  path   = find_in_parent_folders("root.hcl", "gcp/root.hcl")
  expose = true
}

dependency "cloud_apis" {
  config_path  = "../cloud_apis"
  mock_outputs = {
    enabled_api_services = []
  }
}

dependency "shared_vpc" {
  config_path  = "../shared_vpc"
  mock_outputs = {
    network_name         = ""
    network_self_link    = ""
    subnet_name          = ""
    subnet_ip_cidr_range = ""
    subnet_self_link     = ""
    project_id           = ""
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.gke
  )
}

inputs = local.merged_inputs

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../gke"
}

skip = !local.merged_inputs.enabled