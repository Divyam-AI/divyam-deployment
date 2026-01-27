#----------------------------------------------
# Secrets Module (Multi-Cloud)
# GCP: secrets (Secret Manager) | Azure: azure_key_vault | AWS: secrets_manager
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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/secrets"
}

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
    gcp   = "secrets"
    azure = "azure_key_vault"
    aws   = "secrets_manager"
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
