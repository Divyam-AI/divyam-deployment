include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../helm_charts"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

# To ensure the state backend storage is setup.
dependency "azure_blob_storage" {
  config_path = "../azure_blob_storage"
}

dependency "aks" {
  config_path = "../aks"
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"
}

dependency "azure_key_vault_secrets" {
  config_path = "../azure_key_vault_secrets"
}

dependency "aks_namespaces" {
  config_path = "../aks_namespaces"

  mock_outputs = {
    aks_namespaces_output = "mock-aks_namespaces-output"
  }
}

dependency "iam_bindings" {
  config_path = "../iam_bindings"
}

dependency "dns" {
  config_path = "../dns"
}

dependency "app_gw" {
  config_path = "../app_gw"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.helm_charts,
  )
}

inputs = merge(local.merged_inputs, {
  aks_kube_config                             = dependency.aks.outputs.aks_kube_config
  azure_key_vault_id                          = dependency.azure_key_vault.outputs.azure_key_vault_id
  azure_key_vault_uri                         = dependency.azure_key_vault.outputs.azure_key_vault_uri
  uai_client_ids                              = dependency.iam_bindings.outputs.uai_client_ids
  azure_router_logs_storage_connection_string = dependency.azure_blob_storage.outputs.router_logs_storage_account_connection_string
  azure_router_logs_storage_account_name = dependency.azure_blob_storage.outputs.router_logs_storage_account_name

  # TODO: Using the first container as the logs container.
  azure_router_logs_container_name            = dependency.azure_blob_storage.outputs.router_logs_container_names[0]
  router_dns_zone                             = dependency.dns.outputs.router_dns_zone
  dashboard_dns_zone                          = dependency.dns.outputs.dashboard_dns_zone
  app_gateway_tls_enabled                     = dependency.app_gw.outputs.app_gateway_tls_enabled
  app_gateway_certificate_name                = dependency.app_gw.outputs.app_gateway_tls_enabled ? dependency.app_gw.outputs.app_gateway_certificate_name:null
})

skip = !local.merged_inputs.enabled
