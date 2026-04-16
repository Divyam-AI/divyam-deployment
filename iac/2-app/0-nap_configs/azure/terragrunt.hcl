# NAP (Node Auto-Provisioning) Karpenter NodePools + GPU device plugin.
# Separated from 1-k8s so that `plan` does not require a running AKS cluster;
# the cluster is consumed via a terragrunt dependency on 1-platform/1-k8s.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

# OpenTofu allows only one required_providers block per module;
# override root's generated provider.tf with just what this module needs.
generate "provider_nap" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}
EOT
}

dependency "k8s" {
  config_path = "../../../1-platform/1-k8s/azure"
  mock_outputs = {
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
  root = include.root.locals.merged
}

inputs = {
  kube_config = dependency.k8s.outputs.aks_kube_config
  nap_common_tags = try(include.root.inputs.common_tags, {})
  nap_tag_globals = try(include.root.inputs.tag_globals, {})
  cpu_instance_types = try(local.root.k8s.cpu_instance_types, [
              # Standard D Series  
              "Standard_D8s_v6","Standard_D8s_v5", "Standard_D8s_v4","Standard_D8s_v3", "Standard_D8s_v2",
              "Standard_D16s_v6", "Standard_D16s_v5", "Standard_D16s_v4","Standard_D16s_v3", "Standard_D16s_v2", 
              
              # Standard D AS Series  
              "Standard_D8as_v6","Standard_D8as_v5", "Standard_D8as_v4","Standard_D8as_v3", "Standard_D8as_v2",              
              "Standard_D16as_v6","Standard_D16as_v5", "Standard_D16as_v4","Standard_D16as_v3", "Standard_D16as_v2",

              # Standard E Series  
              "Standard_E8s_v6", "Standard_E8s_v5", "Standard_E8s_v4","Standard_E8s_v3", "Standard_E8s_v2",
              "Standard_E16s_v6", "Standard_E16s_v5", "Standard_E16s_v4","Standard_E16s_v3", "Standard_E16s_v2",

              # Standard E AS Series  
              "Standard_E8as_v6","Standard_E8as_v5", "Standard_E8as_v4","Standard_E8as_v3", "Standard_E8as_v2",
              "Standard_E16as_v6","Standard_E16as_v5", "Standard_E16as_v4","Standard_E16as_v3", "Standard_E16as_v2"
              ])

  nap_tag_context = {
    resource_name = local.root.deployment_prefix
  }
}
