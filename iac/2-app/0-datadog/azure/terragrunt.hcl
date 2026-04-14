include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "k8s" {
  config_path = "../../../1-platform/1-k8s/azure"
  mock_outputs = {
    aks_cluster_name = "mock-aks-cluster"
    aks_kube_config = {
      host                   = "https://mock-aks-cluster"
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root            = include.root.locals.merged
  datadog_cfg     = try(local.root.datadog, {})
  datadog_enabled = try(local.datadog_cfg.enabled, false)
}

inputs = {
  cluster_name    = try(dependency.k8s.outputs.aks_cluster_name, local.root.k8s.name)
  kube_config     = dependency.k8s.outputs.aks_kube_config
  datadog_enabled = local.datadog_enabled
  datadog_site    = trimspace(try(local.datadog_cfg.registry, ""))
  datadog_env     = trimspace(try(local.datadog_cfg.env, ""))
  datadog_api_key = get_env("TF_VAR_datadog_api_key", "")
}

exclude {
  if      = !local.datadog_enabled
  actions = ["apply", "plan", "destroy", "refresh", "import"]
}
