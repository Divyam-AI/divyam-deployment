# Shared dependency on 1-k8s/<cloud> for 2-monitoring children.
# Include from child terragrunt.hcl alongside include "root" (each include is one level only).
#
#   include "root" { path = find_in_parent_folders("root.hcl"); expose = true }
#   include "k8s_dep" { path = "${get_parent_terragrunt_dir()}/../../k8s_dependency.hcl" }

locals {
  repo_root   = get_repo_root()
  values_file = get_env("VALUES_FILE")
  values      = read_terragrunt_config("${local.repo_root}/iac/${local.values_file}").locals
  cloud       = try(local.values.cloud_provider, get_env("CLOUD_PROVIDER", "azure"))
}

dependency "k8s" {
  config_path = "../1-k8s/${local.cloud}"

  mock_outputs = local.cloud == "azure" ? {
    aks_cluster_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.ContainerService/managedClusters/mock"
    aks_cluster_name = "mock-aks-cluster"
    aks_kube_config = {
      host                   = "https://mock-aks-cluster"
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
    cluster_endpoints       = {}
    cluster_ca_certificates = {}
  } : {
    aks_cluster_id   = ""
    aks_cluster_name = ""
    aks_kube_config = {
      host                   = ""
      client_certificate     = ""
      client_key             = ""
      cluster_ca_certificate = ""
    }
    cluster_endpoints = {
      mock = "mock-gke-endpoint"
    }
    cluster_ca_certificates = {
      mock = "mock-cluster-ca-cert"
    }
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}
