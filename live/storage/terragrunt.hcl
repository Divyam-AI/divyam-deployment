#----------------------------------------------
# Storage Module (Multi-Cloud)
# GCP: gcs | Azure: azure_blob_storage | AWS: s3
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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/storage"
}

dependency "bootstrap" {
  config_path  = "../_bootstrap"
  skip_outputs = true

  mock_outputs = {
    enabled_api_services = []
  }
}

dependency "network" {
  config_path  = "../network"
  skip_outputs = include.root.locals.cloud_provider != "azure"

  mock_outputs = {
    vnet_id    = ""
    subnet_ids = {}
  }
}

locals {
  module_config_keys = {
    gcp   = "gcs"
    azure = "azure_blob_storage"
    aws   = "s3"
  }

  config_key = local.module_config_keys[include.root.locals.cloud_provider]

  merged_inputs = merge(
    try(include.root.locals.install_config.common_vars, {}),
    try(include.root.locals.install_config[local.config_key], {})
  )

  enabled = try(local.merged_inputs.enabled, true)
}

inputs = merge(
  local.merged_inputs,
  include.root.locals.cloud_provider == "azure" ? {
    subnet_ids = dependency.network.outputs.subnet_ids
  } : {}
)

skip = !local.enabled
