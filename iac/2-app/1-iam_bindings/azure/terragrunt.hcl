# IAM bindings (Azure): User Assigned Identities, RBAC, Key Vault access, and federated credentials for workload identity.
# Depends on: divyam_secrets (Key Vault). Storage account ID and AKS OIDC issuer are fetched from Azure using names from defaults.hcl.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/iac/2-app/1-iam_bindings//azure"
}

dependency "divyam_secrets" {
  config_path = "../../0-divyam_secrets/azure"
  mock_outputs = {
    key_vault_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
  }
}

locals {
  root = include.root.locals.merged
  # From defaults.hcl: storage account name for router-requests-logs; AKS cluster name. Fetched from Azure in Terraform via data sources.
  router_logs_storage_account_name = try(one([for s in local.root.divyam_object_storages : s.storage_account_name if s.type == "router-requests-logs"]), null)
  aks_cluster_name                 = try(local.root.k8s.name, null)
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
  azure_key_vault_id                  = dependency.divyam_secrets.outputs.key_vault_id
  router_logs_storage_account_name    = local.router_logs_storage_account_name
  aks_cluster_name                   = local.aks_cluster_name
}