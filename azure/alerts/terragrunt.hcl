include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../alerts"
}

# To ensure the state backend storage is setup.
dependency "tfstate_azure_blob_storage" {
  config_path = "../tfstate_azure_blob_storage"
}

dependency "aks" {
  config_path = "../aks"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.alerts,
  )
}

inputs = merge(local.merged_inputs, {
  aks_cluster_name                            = include.root.locals.install_config.helm_charts.aks_cluster_name
  azure_monitor_workspace_name                     = dependency.aks.outputs.monitor_workspace_names[include.root.locals.install_config.helm_charts.aks_cluster_name]
  azure_monitor_workspace_id                     = dependency.aks.outputs.monitor_workspace_ids[include.root.locals.install_config.helm_charts.aks_cluster_name]
})

skip = !local.merged_inputs.enabled
