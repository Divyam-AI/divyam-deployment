#----------------------------------------------
# Unified Multi-Cloud Terragrunt Root Configuration
# Supports: GCP, Azure (extensible to AWS, etc.)
#
# Usage:
#   CLOUD_PROVIDER=gcp ENV=prod terragrunt run-all plan
#   CLOUD_PROVIDER=azure ENV=dev terragrunt run-all plan
#----------------------------------------------

locals {
  # Provider selection - defaults to gcp for backward compatibility
  cloud_provider = get_env("CLOUD_PROVIDER", "gcp")
  env_name       = get_env("ENV", "dev")

  # Load provider-specific configuration
  provider_config = read_terragrunt_config(
    "${get_repo_root()}/providers/${local.cloud_provider}/provider.hcl"
  ).locals

  # Load environment-specific configuration
  env_config = read_terragrunt_config(
    "${get_repo_root()}/envs/${local.cloud_provider}/${local.env_name}.hcl"
  ).locals

  # Merge provider defaults with environment config
  # Environment config takes precedence
  install_config = merge(
    local.provider_config.defaults,
    local.env_config
  )

  # Common derived values (accessible to all modules)
  environment = local.env_name
  region      = try(local.install_config.common_vars.region, local.install_config.region, local.install_config.location, "")

  # Provider-specific values exposed for child modules
  # GCP
  project_id = try(local.install_config.common_vars.project_id, local.install_config.project_id, "")

  # Azure
  location             = try(local.install_config.location, local.region, "")
  resource_group_name  = try(local.install_config.resource_group_name, "")
  resource_name_prefix = try(local.install_config.resource_name_prefix, "")
  common_tags          = try(local.install_config.common_tags, {})

  # Backend configuration from provider
  backend_type   = local.provider_config.backend_type
  backend_config = local.provider_config.backend_config
}

# Dynamic remote state based on provider
remote_state {
  backend = local.backend_type
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = local.backend_config
}

# Generate provider block dynamically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = local.provider_config.provider_block
}

# Shared inputs available to all child modules
inputs = {
  # Common inputs
  environment    = local.environment
  cloud_provider = local.cloud_provider

  # GCP inputs
  region     = local.region
  project_id = local.project_id

  # Azure inputs
  location             = local.location
  resource_group_name  = local.resource_group_name
  resource_name_prefix = local.resource_name_prefix
  common_tags          = local.common_tags
}
