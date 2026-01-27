#----------------------------------------------
# Bootstrap Module (Multi-Cloud)
# GCP: cloud_apis | Azure: resource_group | AWS: account_setup
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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/_bootstrap"
}

# Bootstrap modules may need local state (Azure circular dependency)
remote_state {
  backend = contains(try(include.provider.locals.bootstrap_modules, []), "_bootstrap") ? "local" : include.root.locals.backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = contains(try(include.provider.locals.bootstrap_modules, []), "_bootstrap") ? {
    path = "terraform.tfstate"
  } : include.root.locals.backend_config
}

locals {
  # Module config key mapping
  module_config_keys = {
    gcp   = "cloud_apis"
    azure = "resource_group"
    aws   = "account_setup"
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
