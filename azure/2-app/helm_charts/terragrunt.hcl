include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../helm_charts"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
}

# To ensure the state backend storage is setup.
dependency "azure_blob_storage" {
  config_path = "../../1-platform/azure_blob_storage"

  mock_outputs = {
    router_logs_storage_account_connection_string = "mock-connection-string"
    router_logs_storage_account_name              = "mock-storage-account"
    router_logs_container_names                   = ["mock-container"]
  }
}

dependency "aks" {
  config_path = "../../1-platform/aks"

  mock_outputs = {
    aks_kube_config = {
      host                   = "https://mock-aks-host"
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
  }
}

dependency "azure_key_vault" {
  config_path = "../../1-platform/azure_key_vault"

  mock_outputs = {
    azure_key_vault_id  = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
    azure_key_vault_uri = "https://mock-key-vault.vault.azure.net/"
  }
}

dependency "azure_key_vault_secrets" {
  config_path  = "../../1-platform/azure_key_vault_secrets"
  skip_outputs = true
}

dependency "aks_namespaces" {
  config_path  = "../aks_namespaces"
  skip_outputs = true
}

dependency "iam_bindings" {
  config_path = "../../1-platform/iam_bindings"

  mock_outputs = {
    uai_client_ids = {
      prometheus_uai_client_id        = "mock-prometheus-client-id"
      kafka_connect_uai_client_id     = "mock-kafka-client-id"
      billing_uai_client_id           = "mock-billing-client-id"
      router_controller_uai_client_id = "mock-router-client-id"
      eval_uai_client_id              = "mock-eval-client-id"
      selector_training_uai_client_id = "mock-selector-client-id"
    }
  }
}

dependency "dns" {
  config_path = "../../1-platform/dns"

  mock_outputs = {
    router_dns_zone    = "mock-router.internal"
    dashboard_dns_zone = "mock-dashboard.internal"
  }
}

dependency "app_gw" {
  config_path = "../../1-platform/app_gw"

  mock_outputs = {
    app_gateway_tls_enabled      = false
    app_gateway_certificate_name = null
  }
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
