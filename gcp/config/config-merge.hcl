#----------------------------------------------
# Merges config from defaults, environment specification and correctly
# interpolates config for Divyam GCP components.
#
# Load order (later takes precedence):
# 1. Global defaults: /common.hcl
# 2. GCP defaults: /gcp/config/defaults.hcl
# 3. Common env config: /envs/{env}/common.hcl
# 4. GCP env config: /envs/{env}/gcp.hcl
#----------------------------------------------
locals {
  # Load defaults
  global_defaults_file = "${get_repo_root()}/common.hcl"
  gcp_defaults_file    = "${get_repo_root()}/gcp/config/defaults.hcl"

  global_defaults = try(read_terragrunt_config(local.global_defaults_file).locals, {})
  gcp_defaults    = read_terragrunt_config(local.gcp_defaults_file).locals

  # Load environment specific config
  env_name        = get_env("ENV", "dev")
  default_env_dir = "${get_repo_root()}/envs/"
  custom_env_dir  = get_env("ENV_DIR", local.default_env_dir)

  # Common env config (shared across clouds)
  common_env_config_path = (
    fileexists("${local.custom_env_dir}/${local.env_name}/common.hcl") ?
    "${local.custom_env_dir}/${local.env_name}/common.hcl" :
    "${local.default_env_dir}/${local.env_name}/common.hcl"
  )

  # GCP-specific env config
  gcp_env_config_path = (
    fileexists("${local.custom_env_dir}/${local.env_name}/gcp.hcl") ?
    "${local.custom_env_dir}/${local.env_name}/gcp.hcl" :
    "${local.default_env_dir}/${local.env_name}/gcp.hcl"
  )

  common_env_config = try(read_terragrunt_config(local.common_env_config_path).locals, {})
  gcp_env_config    = try(read_terragrunt_config(local.gcp_env_config_path).locals, {})

  # Merge configs: global defaults -> gcp defaults -> common env -> gcp env
  # NOTE: Using jsonencode/jsondecode pattern to avoid HCL's "Inconsistent conditional
  # result types" error when ternary branches return objects with different attributes.

  # Step 1: Merge global_defaults with gcp_defaults
  merged_config_step1_jsonified = {
    for k in setunion(keys(local.global_defaults), keys(local.gcp_defaults)) :
    k => (
      (can(keys(try(local.global_defaults[k], {}))) && can(keys(try(local.gcp_defaults[k], {})))) ?
      jsonencode(merge(try(local.global_defaults[k], {}), try(local.gcp_defaults[k], {}))) :
      jsonencode(try(local.gcp_defaults[k], try(local.global_defaults[k], null)))
    )
  }

  merged_config_step1 = {
    for k, v in local.merged_config_step1_jsonified :
    k => jsondecode(v)
  }

  # Step 2: Merge step1 with common_env_config
  merged_config_step2_jsonified = {
    for k in setunion(keys(local.merged_config_step1), keys(local.common_env_config)) :
    k => (
      (can(keys(try(local.merged_config_step1[k], {}))) && can(keys(try(local.common_env_config[k], {})))) ?
      jsonencode(merge(try(local.merged_config_step1[k], {}), try(local.common_env_config[k], {}))) :
      jsonencode(try(local.common_env_config[k], try(local.merged_config_step1[k], null)))
    )
  }

  merged_config_step2 = {
    for k, v in local.merged_config_step2_jsonified :
    k => jsondecode(v)
  }

  # Step 3: Merge step2 with gcp_env_config
  merged_config_jsonified = {
    for k in setunion(keys(local.merged_config_step2), keys(local.gcp_env_config)) :
    k => (
      (can(keys(try(local.merged_config_step2[k], {}))) && can(keys(try(local.gcp_env_config[k], {})))) ?
      jsonencode(merge(try(local.merged_config_step2[k], {}), try(local.gcp_env_config[k], {}))) :
      jsonencode(try(local.gcp_env_config[k], try(local.merged_config_step2[k], null)))
    )
  }

  merged_config = {
    for k, v in local.merged_config_jsonified :
    k => jsondecode(v)
  }

  # Pass through merged config with defaults for required fields
  install_config = merge(local.merged_config, {
    env_name     = local.env_name
    common_vars  = local.merged_config.common_vars
    derived_vars = try(local.merged_config.derived_vars, {})
    common_tags  = try(local.merged_config.common_tags, {})

    gcs_remote_state = try(local.merged_config.gcs_remote_state, {
      bucket   = ""
      project  = ""
      location = "asia-south1"
    })
  })
}
