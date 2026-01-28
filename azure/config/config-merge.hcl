#----------------------------------------------
# Merges config from defaults, environment specification and correctly
# interpolates config for Divyam components.
#
# Load order (later takes precedence):
# 1. Global defaults: /config/defaults.hcl
# 2. Azure defaults: /azure/config/defaults.hcl
# 3. Common env config: /envs/{env}/common.hcl
# 4. Azure env config: /envs/{env}/azure.hcl
#----------------------------------------------
locals {
  # Cloud gate - only enable Azure modules when CLOUD=azure (or not set)
  cloud_enabled = get_env("CLOUD", "azure") == "azure"

  # Load defaults
  global_defaults_file = "${get_repo_root()}/config/defaults.hcl"
  azure_defaults_file  = "${get_repo_root()}/azure/config/defaults.hcl"

  global_defaults = try(read_terragrunt_config(local.global_defaults_file).locals, {})
  default_config  = read_terragrunt_config(local.azure_defaults_file).locals

  # Load environment specific config
  env_name        = get_env("ENV", "dev")
  default_env_dir = "${get_repo_root()}/envs/"
  custom_env_dir  = get_env("ENV_DIR", local.default_env_dir)
  custom_helm_values_dir = get_env("HELM_VALUES_DIR", "${get_repo_root()}/azure/helm_values")

  # Common env config (shared across clouds)
  common_env_config_path = (
    fileexists("${local.custom_env_dir}/${local.env_name}/common.hcl") ?
    "${local.custom_env_dir}/${local.env_name}/common.hcl" :
    "${local.default_env_dir}/${local.env_name}/common.hcl"
  )

  # Azure-specific env config
  azure_env_config_path = (
    fileexists("${local.custom_env_dir}/${local.env_name}/azure.hcl") ?
    "${local.custom_env_dir}/${local.env_name}/azure.hcl" :
    "${local.default_env_dir}/${local.env_name}/azure.hcl"
  )

  # Artifacts path (from unified location)
  artifacts_path = (
    fileexists("${local.custom_env_dir}/${local.env_name}/artifacts.yaml") ?
    "${local.custom_env_dir}/${local.env_name}/artifacts.yaml" :
    "${local.default_env_dir}/${local.env_name}/artifacts.yaml"
  )

  # Load env configs
  common_env_config_raw = try(read_terragrunt_config(local.common_env_config_path).locals, {})
  azure_env_config_raw  = try(read_terragrunt_config(local.azure_env_config_path).locals, {})

  # Merge common and azure env configs (azure takes precedence)
  env_config = merge(
    local.common_env_config_raw,
    local.azure_env_config_raw,
    {
      # Set config paths for helm charts
      helm_charts = merge(
        try(local.common_env_config_raw.helm_charts, {}),
        try(local.azure_env_config_raw.helm_charts, {}),
        {
          artifacts_path  = abspath(local.artifacts_path)
          values_dir_path = abspath(local.custom_helm_values_dir)
        }
      )
    }
  )

  # First merge global defaults with azure defaults
  # NOTE: Using jsonencode/jsondecode pattern to avoid HCL's "Inconsistent conditional
  # result types" error when ternary branches return objects with different attributes.
  global_azure_defaults_jsonified = {
    for k in setunion(keys(local.global_defaults), keys(local.default_config)) :
    k => (
      (can(keys(try(local.global_defaults[k], {}))) && can(keys(try(local.default_config[k], {})))) ?
      jsonencode(merge(try(local.global_defaults[k], {}), try(local.default_config[k], {}))) :
      jsonencode(try(local.default_config[k], try(local.global_defaults[k], null)))
    )
  }

  global_azure_defaults = {
    for k, v in local.global_azure_defaults_jsonified :
    k => jsondecode(v)
  }

  # Merge the config with environment specific values taking precedence.
  # Perform a two level merge, instead of just top level key merge.
  # NOTE: Here be dragons. A convoluted method to merge two maps to two levels
  #  all because terragrunt does not allow functions and ternery operator expects
  #  both branches to return values of same type.
  defaults_applied_config_jsonified = {
    for k in setunion(keys(local.global_azure_defaults), keys(local.env_config)) :
    k => (
    # If both sides are maps → merge keys, and if subkeys are maps → merge them again
      (can(keys(try(local.global_azure_defaults[k], {}))) && can(keys(try(local.env_config[k], {})))) ?
      jsonencode({
        for subk in setunion(
          keys(try(local.global_azure_defaults[k], {})),
          keys(try(local.env_config[k], {}))
        ) :
        subk => (
          (can(keys(try(local.global_azure_defaults[k][subk], {}))) && can(keys(try(local.env_config[k][subk], {})))) ?
          jsonencode(merge(
            try(local.global_azure_defaults[k][subk], {}),
            try(local.env_config[k][subk], {})
          )) :
          jsonencode(try(local.env_config[k][subk], try(local.global_azure_defaults[k][subk], null)))
        )
      }) :
      (
      # Fallback → shallow merge
        can(merge(
          try(local.global_azure_defaults[k], {}),
          try(local.env_config[k], {})
        )) ?
        jsonencode(merge(
          try(local.global_azure_defaults[k], {}),
          try(local.env_config[k], {})
        )) :
        jsonencode(try(local.env_config[k], try(local.global_azure_defaults[k], null)))
      )
    )
  }

  defaults_applied_config_json_decode_partial = {
    for k, v in local.defaults_applied_config_jsonified :
    k => (
      can(keys(try(jsondecode(v), {}))) ?
      jsonencode({
        for subk, subv in jsondecode(v) :
        subk => jsondecode(subv)
      }) :
      v
    )
  }

  defaults_applied_config = {
    for k, v in local.defaults_applied_config_json_decode_partial :
    k => jsondecode(v)
  }


  org = try(local.defaults_applied_config.org, "")

  resource_name_prefix = (local.org != "" ?
    "divyam-${local.org}-${local.env_name}" :
    "divyam-${local.env_name}")

  storage_account_name_prefix = (local.org != "" ?
    "divyam${local.org}${local.env_name}" :
    "divyam${local.env_name}")


  # Generate values that need interpolation.
  interpolated_config = {
    environment                 = local.env_name
    resource_name_prefix        = local.resource_name_prefix
    storage_account_name_prefix = local.storage_account_name_prefix
    resource_group_name         = "${local.resource_name_prefix}-rg"


    tfstate_azure_blob_storage = {
      storage_account_name = "${local.storage_account_name_prefix}tfstate"
      storage_container_name = try(local.defaults_applied_config.tf_state_storage_container_name, "tfstate")
    }

    azure_blob_storage = {
      divyam_router_logs_storage_account_name = "${local.storage_account_name_prefix}storage"
    }

    vnet = {
      network_name = "${local.resource_name_prefix}-vnet"
    }

    aks = {
      cluster = {
        name       = "${local.resource_name_prefix}-cluster"
        dns_prefix = "${local.resource_name_prefix}-cluster"
      }
    }

    bastion_host = {
      bastion_name = "${local.resource_name_prefix}-bastion"
    }

    app_gw = {
      backend_service_name = "${local.resource_name_prefix}-app-gw"
    }

    azure_key_vault = {
      key_vault_name = "${local.resource_name_prefix}-vault"
    }

    dns = {
      router_dns_zone = (local.org != "" ?
        "api.${local.env_name}.${local.org}.divyam.local" :
        "${local.env_name}.divyam.local")

      dashboard_dns_zone = (local.org != "" ?
        "dashboard.${local.env_name}.${local.org}.divyam.local" :
        "${local.env_name}.dashboard.divyam.local")
    }

    tls_certs = {
      cert_name = "${local.resource_name_prefix}-cert"
    }
  }

  # Use interpolated values wherever defaults_applied_config does not have values.
  # NOTE: Dragons reflected from above. If there is a better way to deep merge
  # two maps. Please change this.
  install_config_jsonified = {
    for k in setunion(keys(local.interpolated_config), keys(local.defaults_applied_config)) :
    k => (
    # If both sides are maps → merge keys, and if subkeys are maps → merge them again
      (can(keys(try(local.interpolated_config[k], {}))) && can(keys(try(local.defaults_applied_config[k], {})))) ?
      jsonencode({
        for subk in setunion(
          keys(try(local.interpolated_config[k], {})),
          keys(try(local.defaults_applied_config[k], {}))
        ) :
        subk => (
          (can(keys(try(local.interpolated_config[k][subk], {}))) && can(keys(try(local.defaults_applied_config[k][subk], {})))) ?
          jsonencode(merge(
            try(local.interpolated_config[k][subk], {}),
            try(local.defaults_applied_config[k][subk], {})
          )) :
          jsonencode(try(local.defaults_applied_config[k][subk], try(local.interpolated_config[k][subk], null)))
        )
      }) :
      (
      # Fallback → shallow merge
        can(merge(
          try(local.interpolated_config[k], {}),
          try(local.defaults_applied_config[k], {})
        )) ?
        jsonencode(merge(
          try(local.interpolated_config[k], {}),
          try(local.defaults_applied_config[k], {})
        )) :
        jsonencode(try(local.defaults_applied_config[k], try(local.interpolated_config[k], null)))
      )
    )
  }

  install_config_json_decode_partial = {
    for k, v in local.install_config_jsonified :
    k => (
      can(keys(try(jsondecode(v), {}))) ?
      jsonencode({
        for subk, subv in jsondecode(v) :
        subk => jsondecode(subv)
      }) :
      v
    )
  }

  # Base install config before cloud gate
  install_config_base = {
    for k, v in local.install_config_json_decode_partial :
    k => jsondecode(v)
  }

  # Apply cloud gate to all module enabled flags
  # When CLOUD != azure, all modules are disabled
  install_config = merge(local.install_config_base, {
    cloud_enabled = local.cloud_enabled
    env_name      = local.env_name

    resource_group = merge(try(local.install_config_base.resource_group, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.resource_group.enabled, false)
    })

    tfstate_azure_blob_storage = merge(try(local.install_config_base.tfstate_azure_blob_storage, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.tfstate_azure_blob_storage.enabled, false)
    })

    azure_blob_storage = merge(try(local.install_config_base.azure_blob_storage, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.azure_blob_storage.enabled, false)
    })

    vnet = merge(try(local.install_config_base.vnet, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.vnet.enabled, false)
    })

    aks = merge(try(local.install_config_base.aks, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.aks.enabled, false)
    })

    bastion_host = merge(try(local.install_config_base.bastion_host, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.bastion_host.enabled, false)
    })

    helm_charts = merge(try(local.install_config_base.helm_charts, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.helm_charts.enabled, false)
    })

    app_gw = merge(try(local.install_config_base.app_gw, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.app_gw.enabled, false)
    })

    nat = merge(try(local.install_config_base.nat, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.nat.enabled, false)
    })

    azure_key_vault = merge(try(local.install_config_base.azure_key_vault, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.azure_key_vault.enabled, false)
    })

    azure_key_vault_secrets = merge(try(local.install_config_base.azure_key_vault_secrets, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.azure_key_vault_secrets.enabled, false)
    })

    aks_namespaces = merge(try(local.install_config_base.aks_namespaces, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.aks_namespaces.enabled, false)
    })

    iam_bindings = merge(try(local.install_config_base.iam_bindings, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.iam_bindings.enabled, false)
    })

    dns = merge(try(local.install_config_base.dns, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.dns.enabled, false)
    })

    tls_certs = merge(try(local.install_config_base.tls_certs, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.tls_certs.enabled, false)
    })

    alerts = merge(try(local.install_config_base.alerts, {}), {
      enabled = local.cloud_enabled && try(local.install_config_base.alerts.enabled, false)
    })
  })
}
