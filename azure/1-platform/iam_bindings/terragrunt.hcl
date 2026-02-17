include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../iam_bindings"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"

  mock_outputs = {
    azure_key_vault_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
  }
}

dependency "azure_blob_storage" {
  config_path = "../azure_blob_storage"

  mock_outputs = {
    router_logs_storage_account_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock"
  }
}

dependency "aks" {
  config_path = "../aks"

  mock_outputs = {
    aks_kube_config = {
      host                   = "https://mock-aks-host"
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
    aks_oidc_issuer_url = "https://mock-oidc-issuer"
    aks_cluster_name    = "mock-aks-cluster"
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.iam_bindings,

    # To get hold of service accounts to bind to UAI.
    include.root.locals.install_config.helm_charts
  )
}

inputs = merge(local.merged_inputs,
  {
    azure_key_vault_id             = dependency.azure_key_vault.outputs.azure_key_vault_id
    router_logs_storage_account_id = dependency.azure_blob_storage.outputs.router_logs_storage_account_id
    aks_kube_config                = dependency.aks.outputs.aks_kube_config
    aks_oidc_issuer_url            = dependency.aks.outputs.aks_oidc_issuer_url
    aks_cluster_name            = dependency.aks.outputs.aks_cluster_name
  }
)

skip = !local.merged_inputs.enabled