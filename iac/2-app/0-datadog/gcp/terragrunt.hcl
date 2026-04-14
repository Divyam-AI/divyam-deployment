include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "k8s" {
  config_path = "../../../1-platform/1-k8s/gcp"
  mock_outputs = {
    cluster_endpoints = {
      mock = "mock-gke-endpoint"
    }
    cluster_ca_certificates = {
      mock = "mock-cluster-ca-cert"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root            = include.root.locals.merged
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
  cluster_name    = local.root.k8s.name
  cluster_endpoint = try(
    dependency.k8s.outputs.cluster_endpoints[local.cluster_name],
    one(values(dependency.k8s.outputs.cluster_endpoints)),
    ""
  )
  cluster_ca_certificate = try(
    dependency.k8s.outputs.cluster_ca_certificates[local.cluster_name],
    one(values(dependency.k8s.outputs.cluster_ca_certificates)),
    ""
  )
}

inputs = {
  project_id             = local.root.resource_scope.name
  region                 = local.root.region
  cluster_name           = local.cluster_name
  cluster_endpoint       = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate
  datadog_enabled        = local.datadog_enabled
  datadog_site           = trimspace(try(local.datadog_cfg.registry, ""))
  datadog_env            = trimspace(try(local.datadog_cfg.env, ""))
  # Shared exclusions always applied to both logs and metrics.
  datadog_exclude_namespaces = try(local.datadog_cfg.exclude_namespaces, [])
  # Granular lists are additive and appended to shared exclusions in module logic.
  datadog_exclude_namespaces_logs    = try(local.datadog_cfg.exclude_namespaces_logs, [])
  datadog_exclude_namespaces_metrics = try(local.datadog_cfg.exclude_namespaces_metrics, [])
  datadog_api_key        = get_env("TF_VAR_datadog_api_key", "")
}

exclude {
  if      = !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
