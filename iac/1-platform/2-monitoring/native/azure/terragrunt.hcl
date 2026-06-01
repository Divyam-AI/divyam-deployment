# Azure Monitor workspace, Prometheus DCR, Managed Grafana. Runs when datadog.enabled = false.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "k8s_dep" {
  path = "${get_repo_root()}/iac/1-platform/2-monitoring/k8s_dependency.hcl"
}

terraform {
  source = "./"
}

locals {
  root            = include.root.locals.merged
  monitoring_cfg  = try(local.root.monitoring, {})
  native_cfg      = try(local.monitoring_cfg.native, {})
  datadog_enabled = try(local.root.datadog.enabled, false)
  k8s_obs         = try(local.root.k8s.observability, {})

  monitoring_enabled = try(local.monitoring_cfg.create, true)
  native_enabled     = local.monitoring_enabled && !local.datadog_enabled

  create_amw = try(local.native_cfg.create_amw, true)
  amw_name   = try(local.native_cfg.azure_monitor_workspace_name, null)

  use_existing_amw = local.native_enabled && !local.create_amw
  amw_inputs_ok    = !local.use_existing_amw || (local.amw_name != null && local.amw_name != "")
}

inputs = {
  enabled             = local.native_enabled && local.amw_inputs_ok
  location            = local.root.region
  resource_group_name = local.root.resource_scope.name
  cluster_name        = try(dependency.k8s.outputs.aks_cluster_name, local.root.k8s.name)
  aks_cluster_id      = try(dependency.k8s.outputs.aks_cluster_id, null)

  enable_metrics_collection = try(local.native_cfg.enable_metrics, try(local.k8s_obs.enable_metrics, true))

  create_amw                   = local.create_amw
  azure_monitor_workspace_name = local.amw_name
  grafana_endpoint_override    = try(local.native_cfg.grafana_endpoint, null)

  common_tags = try(local.root.common_tags, {})
  tag_globals = try(include.root.inputs.tag_globals, {})
  tag_context = { resource_name = "${local.root.deployment_prefix}-monitoring" }
}

exclude {
  if      = local.datadog_enabled || !local.monitoring_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
