include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../helm_charts"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../tfstate_azure_blob_storage"
  skip_outputs = true
}

# To ensure the state backend storage is setup.
dependency "azure_blob_storage" {
  config_path = "../azure_blob_storage"

  mock_outputs = {
    router_logs_storage_account_connection_string = "DefaultEndpointsProtocol=https;AccountName=mock"
    router_logs_storage_account_name              = "mockstorageaccount"
    router_logs_container_names                   = ["mock-container"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "aks" {
  config_path = "../aks"

  mock_outputs = {
    aks_kube_config = {
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
      host                   = "https://mock-host"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"

  mock_outputs = {
    azure_key_vault_id  = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
    azure_key_vault_uri = "https://mock-vault.vault.azure.net/"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "azure_key_vault_secrets" {
  config_path  = "../azure_key_vault_secrets"
  skip_outputs = true
}

dependency "aks_namespaces" {
  config_path  = "../aks_namespaces"
  skip_outputs = true
}

dependency "iam_bindings" {
  config_path = "../iam_bindings"

  mock_outputs = {
    uai_client_ids = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs = {
    router_dns_zone    = "mock-router.local"
    dashboard_dns_zone = "mock-dashboard.local"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "app_gw" {
  config_path = "../app_gw"

  mock_outputs = {
    app_gateway_tls_enabled      = false
    app_gateway_certificate_name = null
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
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
