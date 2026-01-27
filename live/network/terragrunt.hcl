#----------------------------------------------
# Network Module (Multi-Cloud)
# GCP: shared_vpc | Azure: vnet | AWS: vpc
#----------------------------------------------

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "provider" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/provider.hcl"
  expose = true
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/network"
}

# Override remote_state for Azure bootstrap modules (circular dependency)
remote_state {
  backend = contains(try(include.provider.locals.bootstrap_modules, []), "network") ? "local" : include.root.locals.backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = contains(try(include.provider.locals.bootstrap_modules, []), "network") ? {
    path = "terraform.tfstate"
  } : include.root.locals.backend_config
}

# GCP dependency: cloud_apis
dependency "bootstrap" {
  config_path  = "../_bootstrap"
  skip_outputs = true

  mock_outputs = {
    enabled_api_services = []
  }
}

locals {
  # Module config key mapping
  module_config_keys = {
    gcp   = "shared_vpc"
    azure = "vnet"
    aws   = "vpc"
  }

  config_key = local.module_config_keys[include.root.locals.cloud_provider]

  # Merge common vars with module-specific config
  merged_inputs = merge(
    try(include.root.locals.install_config.common_vars, {}),
    try(include.root.locals.install_config[local.config_key], {})
  )

  enabled = try(local.merged_inputs.enabled, true)
}

inputs = local.merged_inputs

skip = !local.enabled
