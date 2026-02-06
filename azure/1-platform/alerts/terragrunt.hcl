include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../alerts"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path  = "../../0-foundation/tfstate_azure_blob_storage"
  skip_outputs = true
}

dependency "aks" {
  config_path = "../aks"

  mock_outputs = {
    monitor_workspace_name = "mock-workspace"
    monitor_workspace_id   = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Monitor/accounts/mock"
  }
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.alerts,
  )
}

inputs = merge(local.merged_inputs, {
  azure_monitor_workspace_name  = dependency.aks.outputs.monitor_workspace_name
  azure_monitor_workspace_id    = dependency.aks.outputs.monitor_workspace_id
})

skip = !local.merged_inputs.enabled
