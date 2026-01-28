#----------------------------------------------
# Top-level Terragrunt configuration for multi-cloud deployment
# This file provides cloud-agnostic validation and common inputs
#----------------------------------------------
locals {
  cloud_provider = get_env("CLOUD", "azure")
  env_name       = get_env("ENV", "dev")

  valid_clouds = ["azure", "gcp"]
  _validate = contains(local.valid_clouds, local.cloud_provider) ? true : tobool("ERROR: CLOUD must be azure or gcp")
}

inputs = {
  cloud_provider = local.cloud_provider
  environment    = local.env_name
}
