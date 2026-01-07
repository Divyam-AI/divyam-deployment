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

/*
dependency "aks" {
  config_path = "../aks"
}
*/


locals {
  merged_inputs = merge(
    include.root.locals.install_config,
    include.root.locals.install_config.alerts,
  )
}

inputs = merge(local.merged_inputs, {
  # azure_monitor_workspace_name  = dependency.aks.outputs.monitor_workspace_name
  # azure_monitor_workspace_id    = dependency.aks.outputs.monitor_workspace_id
  notification_zenduty_webhook_url = "https://events.zenduty.com/integration/vv0kf/microsoftazure/a3ccb7a9-f502-406f-8ed0-b3c3febe8e9e/"
  resource_group_name = "Pre-Production"
})

skip = !local.merged_inputs.enabled
