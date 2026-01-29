include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../tls_certs"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "azure_key_vault" {
  config_path = "../azure_key_vault"

  mock_outputs = {
    azure_key_vault_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.KeyVault/vaults/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.tls_certs,
  )
}

inputs = merge(local.merged_inputs, {
  azure_key_vault_id = dependency.azure_key_vault.outputs.azure_key_vault_id
  router_dns_zone    = local.merged_inputs.dns.router_dns_zone
  dashboard_dns_zone = local.merged_inputs.dns.dashboard_dns_zone
})

skip = !local.merged_inputs.enabled
