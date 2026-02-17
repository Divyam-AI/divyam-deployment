include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../bastion_host"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "vnet" {
  config_path = "../../0-foundation/vnet"

  mock_outputs = {
    vnet_id         = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock"
    subnet_ids      = {}
    subnet_names    = []
    subnet_prefixes = {}
  }
}

dependency "aks" {
  config_path  = "../aks"
  mock_outputs = {
    aks_kube_config_raw = ""
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.bastion_host,
  )
}

#inputs = local.merged_inputs
inputs = merge(local.merged_inputs, {
  vnet_id         = dependency.vnet.outputs.vnet_id
  subnet_ids      = dependency.vnet.outputs.subnet_ids
  subnet_names    = dependency.vnet.outputs.subnet_names
  subnet_prefixes = dependency.vnet.outputs.subnet_prefixes
  aks_kube_config_raw = dependency.aks.outputs.aks_kube_config_raw
})

skip = !local.merged_inputs.enabled
