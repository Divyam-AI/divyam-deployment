include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../iam_bindings"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"
}

dependency "azure_blob_storage" {
  config_path = "../azure_blob_storage"
}

dependency "aks" {
  config_path = "../aks"
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