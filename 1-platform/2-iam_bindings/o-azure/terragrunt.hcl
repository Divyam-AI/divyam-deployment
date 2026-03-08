# IAM bindings (Azure): User Assigned Identities, RBAC, Key Vault access, and federated credentials for workload identity.
# Depends on: divyam_secrets (Key Vault), divyam_object_storage (router logs), and AKS (OIDC issuer).

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "divyam_secrets" {
  config_path = "../../0-divyam_secrets/azure"
  mock_outputs = {
    key_vault_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
  }
}

dependency "divyam_object_storage" {
  config_path = "../../0-divyam_object_storage/azure"
  mock_outputs = {
    router_requests_logs_storage_account_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# AKS: use 1-old/aks until 1-platform/aks exists.
dependency "aks" {
  config_path = "../../../1-old/aks"
  mock_outputs = {
    aks_oidc_issuer_url = "https://mock-oidc-issuer"
    aks_cluster_name    = "mock-aks-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = include.root.locals.merged
}

inputs = {
  env_name                       = local.root.env_name
  resource_group_name            = local.root.resource_scope.name
  location                       = local.root.region
  environment                    = local.root.env_name
  common_tags                    = try(include.root.inputs.common_tags, {})
  tag_globals                    = try(include.root.inputs.tag_globals, {})
  tag_context = {
    resource_name = local.root.deployment_prefix
  }
  azure_key_vault_id             = dependency.divyam_secrets.outputs.key_vault_id
  router_logs_storage_account_id = dependency.divyam_object_storage.outputs.router_requests_logs_storage_account_id
  aks_oidc_issuer_url            = dependency.aks.outputs.aks_oidc_issuer_url
  aks_cluster_name               = dependency.aks.outputs.aks_cluster_name
}