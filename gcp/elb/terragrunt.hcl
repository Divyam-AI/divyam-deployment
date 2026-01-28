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

dependency "shared_vpc" {
  config_path  = "../shared_vpc"
  skip_outputs = !include.root.locals.install_config.cloud_enabled
  mock_outputs = {
    network_name         = ""
    network_self_link    = ""
    subnet_name          = ""
    subnet_ip_cidr_range = ""
    subnet_self_link     = ""
    project_id           = ""
  }
}

dependency "security" {
  config_path  = "../security"
  skip_outputs = !include.root.locals.install_config.cloud_enabled
  mock_outputs = {
    security_policy_id          = ""
    security_policy_name        = ""
    security_policy_description = ""
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.elb
  )
}

inputs = local.merged_inputs

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../elb"
}

skip = !local.merged_inputs.enabled