include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "gke" {
  config_path = "../gke"
  mock_outputs = {
    cluster_endpoints = {}
    cluster_ca_certificates = {}
  }
}

terraform {
  # Point to the Terraform code that wraps your Helm chart deployment.
  # (This might be a module using the Helm provider.)
  source = "../helm_charts"
}

locals {
  merged_inputs = merge(
    include.root.locals.install_config.common_vars,
    include.root.locals.install_config.helm_charts,
  )
}

inputs = merge(local.merged_inputs,
              {
                cluster_endpoint        = dependency.gke.outputs.cluster_endpoints[local.merged_inputs.k8s_cluster_name]
                cluster_ca_certificate  = dependency.gke.outputs.cluster_ca_certificates[local.merged_inputs.k8s_cluster_name]
              }
          )

skip = !local.merged_inputs.enabled