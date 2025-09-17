include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../monitoring"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "aks" {
  config_path = "../aks"
}


locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.monitoring,
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
  app_gateway_certificate_secret_id           = dependency.app_gw.outputs.certificate_secret_id
})

skip = !local.merged_inputs.enabled
