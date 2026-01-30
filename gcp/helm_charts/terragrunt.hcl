include "root" {
  path   = find_in_parent_folders("root.hcl", "gcp/root.hcl")
  expose = true
}

dependency "gke" {
  config_path  = "../gke"
  mock_outputs = {
    cluster_endpoints       = { (include.root.locals.install_config.derived_vars.k8s_cluster_name) = "10.0.0.1" }
    cluster_ca_certificates = { (include.root.locals.install_config.derived_vars.k8s_cluster_name) = "dGVzdC1jZXJ0aWZpY2F0ZQo=" }
  }
}

# Generate kubernetes and helm providers (moved from main.tf)
generate "k8s_helm_providers" {
  path      = "providers_k8s_helm.tf"
  if_exists = "overwrite"
  contents  = <<EOF
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://$${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }
}
EOF
}

terraform {
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
