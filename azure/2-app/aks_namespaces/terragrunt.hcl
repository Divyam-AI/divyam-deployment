include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../aks_namespaces"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
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
    azure_key_vault_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
  }
}

dependency "azure_key_vault_secrets" {
  config_path  = "../../1-platform/azure_key_vault_secrets"
  skip_outputs = true
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.aks_namespaces,

    # To list all namespaces from artifacts file.
    include.root.locals.install_config.helm_charts
  )
}

inputs = merge(local.merged_inputs,
  {
    aks_kube_config    = dependency.aks.outputs.aks_kube_config
    azure_key_vault_id = dependency.azure_key_vault.outputs.azure_key_vault_id
  }
)

skip = !local.merged_inputs.enabled