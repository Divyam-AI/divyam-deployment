#----------------------------------------------
# Merges config from defaults, environment specification and correctly
# interpolates config for Divyam GCP components.
#
# Load order (later takes precedence):
# 1. Global defaults: /config/defaults.hcl
# 2. GCP defaults: /gcp/config/defaults.hcl
# 3. Common env config: /envs/{env}/common.hcl
# 4. GCP env config: /envs/{env}/gcp.hcl
#----------------------------------------------
locals {
  # Cloud gate - only enable GCP modules when CLOUD=gcp
  cloud_enabled = get_env("CLOUD", "azure") == "gcp"

  # Load defaults
  global_defaults_file = "${get_repo_root()}/config/defaults.hcl"
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

  # Apply cloud gate to all module enabled flags
  # When CLOUD != gcp, all modules are disabled
  install_config = {
    common_vars    = local.merged_config.common_vars
    derived_vars   = try(local.merged_config.derived_vars, {})
    common_tags    = try(local.merged_config.common_tags, {})
    env_name       = local.env_name
    cloud_enabled  = local.cloud_enabled

    gcs_remote_state = try(local.merged_config.gcs_remote_state, {
      bucket   = ""
      project  = ""
      location = "asia-south1"
    })

    cloud_apis = merge(try(local.merged_config.cloud_apis, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.cloud_apis.enabled, false)
    })

    shared_vpc = merge(try(local.merged_config.shared_vpc, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.shared_vpc.enabled, false)
    })

    bastion_host = merge(try(local.merged_config.bastion_host, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.bastion_host.enabled, false)
    })

    cloudsql = merge(try(local.merged_config.cloudsql, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.cloudsql.enabled, false)
    })

    secrets = merge(try(local.merged_config.secrets, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.secrets.enabled, false)
    })

    static_addr = merge(try(local.merged_config.static_addr, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.static_addr.enabled, false)
    })

    nat = merge(try(local.merged_config.nat, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.nat.enabled, false)
    })

    ssl_cert = merge(try(local.merged_config.ssl_cert, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.ssl_cert.enabled, false)
    })

    security = merge(try(local.merged_config.security, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.security.enabled, false)
    })

    gcs = merge(try(local.merged_config.gcs, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.gcs.enabled, false)
    })

    elb = merge(try(local.merged_config.elb, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.elb.enabled, false)
    })

    log_storage = merge(try(local.merged_config.log_storage, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.log_storage.enabled, false)
    })

    proxy_subnet = merge(try(local.merged_config.proxy_subnet, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.proxy_subnet.enabled, false)
    })

    gke = merge(try(local.merged_config.gke, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.gke.enabled, false)
    })

    iam_bindings = merge(try(local.merged_config.iam_bindings, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.iam_bindings.enabled, false)
    })

    cloud_build = merge(try(local.merged_config.cloud_build, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.cloud_build.enabled, false)
    })

    alerts = merge(try(local.merged_config.alerts, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.alerts.enabled, false)
    })

    notification_channels = merge(try(local.merged_config.notification_channels, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.notification_channels.enabled, false)
    })

    helm_charts = merge(try(local.merged_config.helm_charts, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.helm_charts.enabled, false)
    })

    shared_vpc_service_project = merge(try(local.merged_config.shared_vpc_service_project, {}), {
      enabled = local.cloud_enabled && try(local.merged_config.shared_vpc_service_project.enabled, false)
    })
  }
}
