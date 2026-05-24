# Parent config for all 2-monitoring children (datadog/*, native/*).
# Declares the single dependency on 1-k8s so apply order is always: cluster first, then monitoring.
#
# Children must:
#   include "monitoring" { path = "${get_parent_terragrunt_dir()}/../../terragrunt.hcl"; expose = true }
#   include "root"       { path = find_in_parent_folders("root.hcl"); expose = true }
#
# Do NOT add dependency "monitoring" on 1-k8s — that would run monitoring before the cluster.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  root  = include.root.locals.merged
  cloud = local.root.cloud_provider
}

dependency "k8s" {
  config_path = "../1-k8s/${local.cloud}"

  mock_outputs = (
    local.cloud == "azure" ? {
      aks_cluster_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.ContainerService/managedClusters/mock"
      aks_cluster_name = "mock-aks-cluster"
      aks_kube_config = {
        host                   = "https://mock-aks-cluster"
        client_certificate     = ""
        client_key             = ""
        cluster_ca_certificate = ""
      }
    } : {
      cluster_endpoints = {
        mock = "mock-gke-endpoint"
      }
      cluster_ca_certificates = {
        mock = "mock-cluster-ca-cert"
      }
    }
  )

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}
