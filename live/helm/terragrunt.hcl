#----------------------------------------------
# Helm Module (Multi-Cloud)
# GCP: helm_charts | Azure: helm_charts | AWS: helm_charts
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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/providers/${get_env("CLOUD_PROVIDER", "gcp")}/modules/helm"
}

dependency "kubernetes" {
  config_path = "../kubernetes"

  mock_outputs = {
    cluster_endpoints       = {}
    cluster_ca_certificates = {}
    aks_kube_config = {
      host                   = ""
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
  }
}

dependency "secrets" {
  config_path  = "../secrets"
  skip_outputs = include.root.locals.cloud_provider != "azure"

  mock_outputs = {
    azure_key_vault_id  = ""
    azure_key_vault_uri = ""
  }
}

dependency "storage" {
  config_path  = "../storage"
  skip_outputs = include.root.locals.cloud_provider != "azure"

  mock_outputs = {
    router_logs_storage_account_connection_string = ""
    router_logs_storage_account_name              = ""
    router_logs_container_names                   = [""]
  }
}

dependency "iam" {
  config_path  = "../iam"
  skip_outputs = include.root.locals.cloud_provider != "azure"

  mock_outputs = {
    uai_client_ids = {}
  }
}

locals {
  module_config_keys = {
    gcp   = "helm_charts"
    azure = "helm_charts"
    aws   = "helm_charts"
  }

  config_key = local.module_config_keys[include.root.locals.cloud_provider]

  merged_inputs = merge(
    try(include.root.locals.install_config.common_vars, {}),
    try(include.root.locals.install_config.derived_vars, {}),
    try(include.root.locals.install_config[local.config_key], {})
  )

  enabled = try(local.merged_inputs.enabled, true)

  # GCP cluster name for lookups
  k8s_cluster_name = try(local.merged_inputs.k8s_cluster_name, "")
}

inputs = merge(
  local.merged_inputs,
  include.root.locals.cloud_provider == "azure" ? {
    aks_kube_config                             = dependency.kubernetes.outputs.aks_kube_config
    azure_key_vault_id                          = dependency.secrets.outputs.azure_key_vault_id
    azure_key_vault_uri                         = dependency.secrets.outputs.azure_key_vault_uri
    uai_client_ids                              = dependency.iam.outputs.uai_client_ids
    azure_router_logs_storage_connection_string = dependency.storage.outputs.router_logs_storage_account_connection_string
    azure_router_logs_storage_account_name      = dependency.storage.outputs.router_logs_storage_account_name
    azure_router_logs_container_name            = try(dependency.storage.outputs.router_logs_container_names[0], "")
  } : {
    cluster_endpoint       = try(dependency.kubernetes.outputs.cluster_endpoints[local.k8s_cluster_name], "")
    cluster_ca_certificate = try(dependency.kubernetes.outputs.cluster_ca_certificates[local.k8s_cluster_name], "")
  }
)

skip = !local.enabled
