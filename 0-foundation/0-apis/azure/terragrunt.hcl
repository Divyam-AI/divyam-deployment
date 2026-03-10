include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "resource_scope" {
  config_path = "../../0-resource_scope/azure"
}

remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    path = include.root.locals.local_state_file
  }
}

locals {
  root = include.root.locals.merged
  # Optional config from values; defaults match azure/scripts/register_providers.sh
  apis_config = try(local.root.apis, { enabled = true, provider_namespaces = [] })
  default_providers = [
    "Microsoft.ApiManagement",
    "Microsoft.AppConfiguration",
    "Microsoft.AppPlatform",
    "Microsoft.AVS",
    "Microsoft.Cache",
    "Microsoft.Cdn",
    "Microsoft.Compute",
    "Microsoft.CustomProviders",
    "Microsoft.Databricks",
    "Microsoft.DataFactory",
    "Microsoft.DataLakeAnalytics",
    "Microsoft.DataLakeStore",
    "Microsoft.DataProtection",
    "Microsoft.DBforMariaDB",
    "Microsoft.DBforMySQL",
    "Microsoft.Devices",
    "Microsoft.DevTestLab",
    "Microsoft.DocumentDB",
    "Microsoft.EventGrid",
    "Microsoft.Kusto",
    "Microsoft.Logic",
    "Microsoft.ManagedServices",
    "Microsoft.NotificationHubs",
    "Microsoft.OperationsManagement",
    "Microsoft.PowerBIDedicated",
    "Microsoft.RecoveryServices",
    "Microsoft.Relay",
    "Microsoft.Search",
    "Microsoft.SecurityInsights",
    "Microsoft.ServiceBus",
    "Microsoft.SignalRService",
    "Microsoft.StreamAnalytics",
    "Microsoft.Web",
  ]
  provider_namespaces = length(try(local.apis_config.provider_namespaces, [])) > 0 ? local.apis_config.provider_namespaces : local.default_providers
}

inputs = merge(
  {
    enabled           = try(local.apis_config.enabled, true)
    provider_namespaces = local.provider_namespaces
  }
)
