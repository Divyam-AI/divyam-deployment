include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "./"
}

# Terraform does not allow variables in module source; generate file with literal path (same pattern as 0-divyam_secrets/gcp).
generate "common_module" {
  path      = "common_module.tf"
  if_exists = "overwrite"
  contents  = <<EOF
module "datadog_k8s" {
  source = "${get_terragrunt_dir()}/../common"

  datadog_enabled         = var.datadog_enabled
  cluster_name            = var.cluster_name
  datadog_site            = var.datadog_site
  datadog_env             = var.datadog_env
  datadog_api_key         = var.datadog_api_key
  datadog_docker_registry = var.datadog_docker_registry

  datadog_exclude_namespaces         = var.datadog_exclude_namespaces
  datadog_exclude_namespaces_logs    = var.datadog_exclude_namespaces_logs
  datadog_exclude_namespaces_metrics = var.datadog_exclude_namespaces_metrics

  node_agent_jmx_enabled = false
}
EOF
}

# Root generate "provider" already defines terraform { required_providers { google } }. OpenTofu allows only
# one such block per module; *_override.tf merges additional provider constraints into that block.
generate "k8s_providers_override" {
  path      = "zz_datadog_k8s_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
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
EOF
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
  datadog_site           = trimspace(try(local.datadog_cfg.site, ""))
  datadog_docker_registry    = trimspace(try(local.datadog_cfg.docker_registry, "asia.gcr.io/datadoghq"))
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
